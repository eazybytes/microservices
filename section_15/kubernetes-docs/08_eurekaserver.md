# `08_eurekaserver.yml` - the service registry

Two objects: a **Deployment** and a **Service**.

## What this is for

Eureka is a service registry: every microservice registers itself here on startup ("hi, I'm
`accounts`, reach me at this address"), and other services ask Eureka to look each other up
by name instead of hardcoding IP addresses. Every service in this app that talks to another
service (accounts, loans, cards, gatewayserver) points at Eureka via
`EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` in the ConfigMap.

You might wonder why this is needed at all when Kubernetes Services already give every
service a stable DNS name (see [01_configmaps.md](01_configmaps.md) - `kafka`, `redis`,
etc.). This app layers Eureka on top mainly because the underlying Spring Cloud code (load
balancing between multiple instances of the same service, circuit breakers, etc.) is written
against Eureka - Kubernetes Services and Eureka are solving a very similar problem from two
different layers.

## The Deployment

```yaml
containers:
- name: eurekaserver
  image: eazybytes/eurekaserver:s14
  ports:
  - containerPort: 8070
  env:
  - name: SPRING_CONFIG_IMPORT
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: SPRING_CONFIG_IMPORT}}
  - name: MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT
    ...
```
- `SPRING_CONFIG_IMPORT` - unlike `configserver` itself, `eurekaserver` *does* fetch its
  config from the config server on startup, so it needs this pointer.
- The three `OTLP_*`-derived env vars send this service's telemetry to Grafana-LGTM, same
  pattern as every other service in this app.

**Probes/Resources**: identical shape and values to `configserver` - `/actuator/health/*`
probes on port 8070, `250m/384Mi` requests, `500m/700Mi` limits.

## The Service

```yaml
type: LoadBalancer
ports:
  - port: 8070
    targetPort: 8070
```
Same reasoning as configserver's Service: exposed externally mostly for convenience (you can
open `http://<external-ip>:8070` in a browser to see Eureka's dashboard of registered
services), not because outside clients need it for the app to function.
