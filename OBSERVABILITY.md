# Navio Observability Stack

Local observability stack for distributed tracing, metrics collection, log aggregation, and a production-operations dashboard.

## Components

| Service | Port | Purpose | URL |
|---------|------|---------|-----|
| **Zipkin** | 9411 | Distributed tracing backend | http://localhost:9411 |
| **Prometheus** | 9090 | Metrics collection & storage | http://localhost:9090 |
| **Grafana** | 3000 | Visualization dashboard | http://localhost:3000 |
| **Loki** | 3100 | Log aggregation engine | http://localhost:3100 |
| **Alloy** | 12345 | Telemetry collector | http://localhost:12345 |
| **pgAdmin** | 5050 | PostgreSQL management | http://localhost:5050 |

## Quick Start

### 1. Start All Services
```bash
docker compose up -d
```

Verify all services are running:
```bash
docker compose ps
```

### 2. Access Dashboards

**Grafana (Main Dashboard)**
- URL: http://localhost:3000
- Auto-login enabled (no password)
- Dashboard: **Navio Production Overview** in the **Navio** folder
- Shows: service health, RED signals, a 99.9% availability SLO, JVM/database/Kafka saturation, alerts, and logs

The dashboard provides `cluster`, `environment`, and multi-select `service` filters and opens on `api-gateway`, the user-facing SLO boundary. Select **All** for a fleet-wide view. Empty request panels mean there was no matching application traffic; health panels remain independent of traffic so an idle service is not mistaken for a failed service.

### Dashboard alert thresholds

Prometheus loads `prometheus/rules/navio.yml`, which provides recording rules and these dashboard-visible alerts:

| Alert | Default threshold |
|-------|-------------------|
| `NavioServiceDown` | Target unavailable for 2 minutes |
| `NavioHighServerErrorRate` | More than 5% 5xx responses for 5 minutes, with meaningful traffic |
| `NavioHighP95Latency` | p95 above 1 second for 10 minutes, with meaningful traffic |
| `NavioJvmHeapNearlyFull` | Heap above 90% for 10 minutes |
| `NavioDatabasePoolSaturated` | Hikari pool above 90% for 5 minutes |
| `NavioDatabaseConnectionTimeouts` | Continuous acquisition timeouts for 5 minutes |
| `NavioKafkaProducerErrors` | Continuous producer errors for 5 minutes |

These defaults are starting points. Set the SLO and thresholds from measured production behavior before using them for paging.

**Prometheus (Metrics)**
- URL: http://localhost:9090
- Query metrics and view targets

**Zipkin (Traces)**
- URL: http://localhost:9411
- View distributed traces from services

**Loki (Logs)**
- API: http://localhost:3100
- Queried via Grafana

**pgAdmin (Database UI)**
- URL: http://localhost:5050
- Login: `admin@navio.example.com` / `admin`

## Configure Java 25 Microservices

### For Tracing (Zipkin)

All Java services with these dependencies auto-send sampled traces to Zipkin and expose Prometheus metrics:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-zipkin</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
    <scope>runtime</scope>
</dependency>
```

Configure in `application.yml`:
```yaml
spring:
  application:
    name: your-service-name

management:
  metrics:
    distribution:
      percentiles-histogram:
        http.server.requests: true  # Required for p50/p95/p99 panels
  tracing:
    sampling:
      probability: 1.0  # 100% for dev, 0.1 for prod
    export:
      zipkin:
        endpoint: http://localhost:9411/api/v2/spans
  prometheus:
    metrics:
      export:
        enabled: true
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
```

### For Metrics (Prometheus)

Prometheus automatically scrapes host-run services through `host.docker.internal`:
- http://localhost:8080/actuator/prometheus (API Gateway)
- http://localhost:8888/actuator/prometheus (Config Server)
- http://localhost:8761/actuator/prometheus (Discovery Server)
- http://localhost:8082/actuator/prometheus (Trip Planning)
- http://localhost:8083/actuator/prometheus (User Management)

Update `prometheus.yml` with actual service ports if they change.

### For Logs (Loki)

Alloy automatically collects Docker container logs and `server/*/logs/*.log` files from host-run Java services. Configure log levels in services:
```yaml
logging:
  level:
    root: INFO
    com.navio: DEBUG
```

## Grafana Datasources

| Datasource | Type | URL |
|-----------|------|-----|
| Loki | Logs | http://loki:3100 |
| Prometheus | Metrics | http://prometheus:9090 |
| Zipkin | Traces | http://zipkin:9411 |

These data sources and the `Navio Observability Overview` dashboard are provisioned from the repository when Grafana starts.

## Common Tasks

### View Service Traces
1. Open Zipkin: http://localhost:9411
2. Select service from dropdown
3. Click "Find Traces"

### View Service Logs
1. Open Grafana: http://localhost:3000
2. Go to Explore → Loki
3. Query by label: `{container_name="navio-api-gateway"}`

### View Service Metrics
1. Open Prometheus: http://localhost:9090
2. Query metric: `jvm_memory_used{job="api-gateway"}`
3. Or use Grafana dashboards

## Configuration Files

| File | Purpose |
|------|---------|
| `loki-config.yaml` | Single-node Loki TSDB/filesystem config for local development |
| `prometheus.yml` | Prometheus scrape targets & labels |
| `prometheus/rules/navio.yml` | Navio recording and alert rules |
| `alloy-config.alloy` | Alloy Docker and host-file log collectors |
| `grafana/provisioning/` | Provisioned Prometheus, Loki, Zipkin, and dashboards |

## Troubleshooting

**Loki not receiving logs:**
- Check Alloy is running: `docker compose logs alloy`
- Verify Loki is ready: `http://localhost:3100/ready`

**Prometheus metrics empty:**
- Ensure Java services are running and exposing `/actuator/prometheus`
- Check service ports in `prometheus.yml`

**Zipkin traces not appearing:**
- Verify `management.tracing.sampling.probability: 1.0` in Java services
- Check Java service logs for tracing errors

**Grafana dashboards not loading:**
- Check provisioning logs: `docker compose logs grafana`
- Confirm `http://localhost:3000/api/datasources` lists three sources

## Production Considerations

The dashboard is designed for production operations, but this Docker Compose deployment intentionally uses development defaults. Before production deployment:

1. Disable anonymous Grafana Admin access and configure SSO/RBAC.
2. Connect Prometheus alerts to Alertmanager or another notification route; rules alone do not page anyone.
3. Replace local Prometheus/Loki storage with durable storage and configure retention.
4. Set a lower trace sampling rate based on traffic and investigation needs.
5. Put cluster and environment labels on every production scrape target and log stream.
6. Store credentials in a secret manager and set container resource limits.
7. Monitor Prometheus, Loki, Alloy, and Grafana as production services themselves.

## Docker Compose Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f [service-name]

# Restart a service
docker compose restart [service-name]

# Stop everything
docker compose down

# Remove all data (fresh start)
docker compose down -v
```

## Next Steps

1. Start docker-compose: `docker compose up -d`
2. Access Grafana: http://localhost:3000
3. Run your Java microservices
4. View traces, metrics, and logs in real-time
