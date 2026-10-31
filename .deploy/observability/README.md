# Production monitoring diagnosis

Open `https://navio.sit.kmutt.ac.th/grafana/` and sign in with the existing Grafana account. Prometheus, Loki and Tempo are private Docker services; access their data through Grafana Explore using the corresponding datasource. Their ports are intentionally not public.

On the VM run `bash .deploy/scripts/check-observability.sh` from a source checkout, or copy that single script to the VM and run it. It reads host/container memory, restart/OOM state, actual backend readiness, scrape targets, recent log counts and trace service names. It does not print secrets or log contents, pull images, or restart services. An empty log/trace result is not conclusive: quiet services and 10% trace sampling can produce empty short windows.

If Grafana is healthy but its panels fail, check the actual datasource query error in the browser. A successful `/grafana/api/health` response only proves Grafana and its database are alive. Select the `production` environment and an appropriate time range. Distinguish a failed query from a successful query with no samples.

If Prometheus reports a down target, inspect that specific service and its `/actuator/prometheus` response on the private network. If Loki/Alloy readiness fails, inspect their local container logs on the VM; redact any credentials or user content before sharing. Current Compose checks that execute `loki -version` or `alloy --version` do not verify ingestion. Tempo has no Compose health gate, so verify `/ready` and that real sampled traffic produces traces.

## Service graph

`Navio > Navio Service Graph` (`/grafana/d/navio-service-graph`) draws which service calls which. The path is: services export Zipkin spans to Alloy on `alloy:9411`, Alloy drops `/actuator` probe spans and forwards OTLP to Tempo, and Tempo's metrics generator remote-writes `traces_service_graph_*` and `traces_spanmetrics_*` to Prometheus (`--web.enable-remote-write-receiver`). The node graph panel uses the Tempo datasource's Service Graph query, which reads those series from Prometheus. With 10% sampling, edges need a few minutes of real traffic. The `user` node is where a request entered the system. If the graph is empty but traces exist, run the "Service graph edges" probe in `check-observability.sh`.

## Infrastructure dashboard

`Navio > Navio Infrastructure` (`/grafana/d/navio-infrastructure`) shows VM CPU, memory, swap, disk and pressure (PSI); every container's memory working set against its `mem_limit`, plus CPU, network, disk I/O, restarts and OOM events; how each JVM's heap, non-heap and native memory fit in its container; and per-service request rate and p50/p95/p99 latency.

Host metrics come from Alloy's built-in `prometheus.exporter.unix`, reading the host `/proc`, `/sys` and `/` mounted read-only into Alloy. Container metrics come from the `cadvisor` service, which Alloy scrapes. Both go through one `prometheus.relabel` filter that keeps only the series the dashboard uses (about 300) and maps each container's Compose service name to the `service` label, the same label the actuator scrapes carry. Alloy then remote-writes them to Prometheus.

cAdvisor runs as its own container, not Alloy's `prometheus.exporter.cadvisor`. Docker on the VM uses the containerd image store (`docker info` reports storage driver `overlayfs`, `io.containerd.snapshotter.v1`). The cAdvisor bundled in Alloy v1.12 predates support for it and registers no containers, logging `failed to identify the read-write layer ID`. Standalone cAdvisor v0.54+ supports it, given the containerd socket.

The local stack has no node exporter or cAdvisor, so this dashboard is empty there.

## Config changes on deploy

`deploy.sh` stores a digest of each observability service's mounted config in `.env` (`NAVIO_<SERVICE>_CONFIG_REVISION`), and Compose puts it on the container as the `io.navio.config-revision` label. When a config file changes, the label changes and `compose up` recreates that service. Without it, Prometheus, Loki, Tempo, Grafana and Alloy kept running the previous config after a deploy, because their images are pinned and their single-file mounts stay on the replaced file. New dashboard JSON needs no restart: Grafana rescans `grafana/dashboards/` every minute.

## Memory budget

The current production Compose limits sum to **9,296 MiB**, including **1,812 MiB** for Prometheus (400), Loki (350), Tempo (384), Grafana (300), Alloy (250) and cAdvisor (128). Persistent community storage adds **384 MiB**, for **9,680 MiB** total, before the host, Docker, runner, and the temporary storage initialization container (128 MiB). These are ceilings, not allocations or measured usage. Optional Compose services may not all be running.

The README describes an 8 GB application VM. That does not provide enough RAM for every container to reach its ceiling simultaneously. Use actual `MemAvailable`, swap use, `docker stats`, OOM/restart history and representative traffic before enabling additional services or increasing limits. Do not reduce application heaps blindly to make the arithmetic fit. Monitoring is already declared in the production stack; first establish which services are actually running and consuming memory.

Keep trace sampling at 0.1 unless a measured short diagnostic requires more. Tempo keeps 24 hours of traces on its `tempo-data` volume. Prometheus disk retention and Loki log retention constrain storage; they do not guarantee bounded query memory. If sustained usage leaves insufficient application/host headroom, move monitoring to another host or increase VM memory before expanding collection. Any sizing decision remains provisional until live measurements are available.

### User-supplied VM snapshot, 2026-10-30

The VM reports 7,935 MiB RAM and 1,921 MiB available. All five monitoring services are already running, with combined Docker-reported memory usage of 567.91 MiB. This snapshot does not show immediate host RAM exhaustion. Swap holds 2,047 MiB; occupancy alone does not establish current swapping. Check subsequent `vmstat 1 5` rows for swap-in/swap-out activity and sample during actual traffic.

User-management reports 484.1/500 MiB (96.82%) and community 470.9/500 MiB (94.18%). Those individual container limits warrant investigation even while the host has available memory. Do not conclude these services have been OOM-killed from percentages alone. The supplied container status shows all configured health checks passing, but the monitoring checks have the limitations described above. Actual scrape targets, log ingestion, trace data, and the failing Grafana query remain to be checked.
