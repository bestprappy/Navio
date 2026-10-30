#!/usr/bin/env bash
# Read-only: no env files, credentials, log messages, restarts or image pulls.
# Run on the VM: bash check-observability.sh
set -Eeuo pipefail

printf '\nHost memory (MiB)\n'
free -m
printf '\nSwap activity (ignore the first, since-boot vmstat row)\n'
vmstat 1 5
printf '\nDisk capacity\n'
df -h / /var/lib/docker
printf '\nContainer usage\n'
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}'
printf '\nNavio container state (limits are bytes, not reserved memory)\n'
mapfile -t containers < <(docker ps -aq --filter label=com.docker.compose.project=navio)
if ((${#containers[@]})); then
  docker inspect --format '{{.Name}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} oom={{.State.OOMKilled}} restarts={{.RestartCount}} limit={{.HostConfig.Memory}}' "${containers[@]}"
fi

# Reuse Node in the running web container to query the private network. No new
# container, credentials or publicly exposed monitoring ports are needed.
mapfile -t web < <(docker ps -q \
  --filter label=com.docker.compose.project=navio \
  --filter label=com.docker.compose.service=navio-web)
if ((${#web[@]} != 1)); then
  echo 'Expected one running navio-web container for private-network probes.' >&2
  exit 1
fi

docker exec -i "${web[0]}" node --input-type=module <<'NODE'
let failures = 0;
async function probe(name, url, summarize) {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const result = summarize ? summarize(await response.json()) : 'ready';
    console.log(`${name}: ${JSON.stringify(result)}`);
  } catch (error) {
    failures++;
    console.log(`${name}: FAILED ${error.message}${error.cause?.code ? ` (${error.cause.code})` : ''}`);
  }
}
// Sequential probes keep the diagnostic itself cheap on a constrained VM.
await probe('Grafana', 'http://grafana:3000/grafana/api/health', body => ({ database: body.database, version: body.version }));
await probe('Prometheus readiness', 'http://prometheus:9090/-/ready');
await probe('Loki readiness', 'http://loki:3100/ready');
await probe('Alloy readiness', 'http://alloy:12345/-/ready');
await probe('Tempo readiness', 'http://tempo:3200/ready');
await probe('Scrape targets', 'http://prometheus:9090/api/v1/targets?state=active', body => {
  if (body.status !== 'success') throw new Error('Prometheus query failed');
  const targets = body.data.activeTargets;
  if (!targets.length || targets.some(target => target.health !== 'up')) failures++;
  return targets.map(target => ({
    job: target.labels.job, health: target.health,
    lastScrape: target.lastScrape, error: target.lastError,
  }));
});
await probe('Recent log counts (no log content)', 'http://loki:3100/loki/api/v1/query?' + new URLSearchParams({
  query: 'sum by (service_name) (count_over_time({cluster="navio",environment="production"}[15m]))',
}), body => {
  if (body.status !== 'success') throw new Error('Loki query failed');
  return { streams: body.data.result, note: 'Empty can mean no logs in the last 15 minutes; check Alloy and time range.' };
});
await probe('Recent trace services', 'http://tempo:3200/api/search/tag/service.name/values', body => ({
  services: body.tagValues, note: 'Only sampled requests produce traces; Alloy drops /actuator probes.',
}));
await probe('Service graph edges', 'http://prometheus:9090/api/v1/query?' + new URLSearchParams({
  query: 'sum by (client, server) (rate(traces_service_graph_request_total[15m]))',
}), body => {
  if (body.status !== 'success') throw new Error('Prometheus query failed');
  return { edges: body.data.result.map(r => `${r.metric.client} -> ${r.metric.server}`), note: 'Empty means no sampled service-to-service traffic in 15 minutes, or Tempo cannot remote-write to Prometheus.' };
});
process.exitCode = failures ? 1 : 0;
NODE
