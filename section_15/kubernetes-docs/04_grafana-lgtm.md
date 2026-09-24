# `04_grafana-lgtm.yml` - observability stack

Two objects in this file: a **Deployment** and a **Service**.

## What this is for

`grafana/otel-lgtm` is an all-in-one image bundling **L**oki (logs), **G**rafana
(dashboards), **T**empo (traces), and **M**imir (metrics), plus an OpenTelemetry (OTLP)
collector to receive data. Every other Spring Boot service in this app is configured (via
the `OTLP_*` keys in the ConfigMap) to send its traces, logs, and metrics here, so you get
one place to look at what the whole system is doing.

## Why there's no PersistentVolumeClaim

This setup is meant for local testing and demos, so Grafana's data is **not** persisted.
The container writes dashboards, metrics, logs and traces to its own filesystem, and
all of it is lost whenever the pod restarts or is recreated. For a demo that's fine,
because the services start sending fresh telemetry as soon as Grafana is back up.

If you need the data to survive restarts (for example, in a shared or long-lived
environment), add a PVC and mount it at `/data` in the container.

## The Deployment

```yaml
containers:
  - name: grafana-lgtm
    image: grafana/otel-lgtm:0.29.2
    ports:
      - name: ui
        containerPort: 3000
      - name: otlp-grpc
        containerPort: 4317
      - name: otlp-http
        containerPort: 4318
```
- Three ports serve three different purposes: `3000` is the Grafana web UI you'd open in a
  browser; `4317` and `4318` are where other services send telemetry data - `4317` for
  OTLP-over-gRPC, `4318` for OTLP-over-HTTP (this app's services use the HTTP one, per the
  ConfigMap's `OTLP_*` URLs).

**Probes**: all three probes call `GET /api/health` on port 3000 - Grafana's own built-in
health endpoint. The `startupProbe` has a generous `failureThreshold: 30` (at 5s apart, up
to 2.5 minutes) because this bundled image has a lot to boot up before it's ready.

**Resources**: this is the heaviest thing in the whole app (`memory limit: 1536Mi`) because
it's really four services (Loki+Grafana+Tempo+Mimir) bundled into one image.

## The Service

```yaml
type: LoadBalancer
ports:
  - name: ui
    port: 3000
  - name: otlp-grpc
    port: 4317
  - name: otlp-http
    port: 4318
```
Unlike Redis, this one is `type: LoadBalancer` - the intent is that a person can open the
Grafana UI (port 3000) from outside the cluster, in a browser, to look at dashboards. The
other two ports (4317/4318) tag along on the same Service mainly so other pods can reach
them at the same `grafana-lgtm` hostname - they don't strictly need to be reachable from
*outside* the cluster, only from other pods.
