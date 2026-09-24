# `07_configserver.yml` - the config server

Two objects: a **Deployment** and a **Service**.

## What this is for

Spring Cloud Config Server hands out configuration files to every other microservice at
startup, so config changes don't require rebuilding an image - just changing what the
config server serves. Every other business service in this app (accounts, loans, cards,
eurekaserver, gatewayserver) points at this via `SPRING_CONFIG_IMPORT` in the ConfigMap.
Because it *is* the thing that hands out config, it can't fetch its own config from itself -
that's why, unlike the other services, it has no `SPRING_CONFIG_IMPORT` or
`SPRING_PROFILES_ACTIVE` env var wired in here.

## The Deployment

```yaml
containers:
- name: configserver
  image: eazybytes/configserver:s14
  ports:
  - containerPort: 8071
  env:
  - name: MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: OTLP_TRACES_ENDPOINT}}
  - name: MANAGEMENT_OPENTELEMETRY_LOGGING_EXPORT_OTLP_ENDPOINT
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: OTLP_LOGS_ENDPOINT}}
  - name: MANAGEMENT_OTLP_METRICS_EXPORT_URL
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: OTLP_METRICS_ENDPOINT}}
```
- `image: eazybytes/configserver:s14` - the app image, tagged `s14` (this course's section-14
  build). Bumping this tag is how you deploy a new version of the code.
- The three `MANAGEMENT_OPENTELEMETRY_*`/`MANAGEMENT_OTLP_*` env vars point this service at
  the Grafana-LGTM stack ([`04_grafana-lgtm.yml`](04_grafana-lgtm.md)) so its traces, logs,
  and metrics show up there.

**Probes**: `startupProbe`/`readinessProbe` hit `GET /actuator/health/readiness`;
`livenessProbe` hits `GET /actuator/health/liveness`, both on port 8071. These endpoints
come from Spring Boot Actuator and are automatically split into "readiness" (dependencies
OK, can serve traffic) vs "liveness" (process itself hasn't deadlocked) groups once Spring
Boot detects it's running inside Kubernetes.

**Resources**: `requests: 250m CPU / 384Mi memory`, `limits: 500m CPU / 700Mi memory` - the
standard allowance used for every plain microservice in this app.

## The Service

```yaml
type: LoadBalancer
ports:
  - port: 8071
    targetPort: 8071
```
Exposed externally mainly so you can poke at `configserver`'s own actuator/config endpoints
directly while developing - in a real deployment this and the other internal services
(eureka, accounts, loans, cards) typically wouldn't need to be reachable from outside the
cluster at all, only from the gateway and each other.
