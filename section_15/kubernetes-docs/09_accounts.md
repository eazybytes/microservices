# `09_accounts.yml` - the accounts microservice

Two objects: a **Deployment** and a **Service**.

## What this is for

This runs the actual accounts business logic - creating/reading/updating bank accounts. It's
the first of three "business" microservices in this app (alongside loans and cards).

## The Deployment

```yaml
containers:
- name: accounts
  image: eazybytes/accounts:s14
  ports:
  - containerPort: 8080
  env:
  - name: SPRING_PROFILES_ACTIVE
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: SPRING_PROFILES_ACTIVE}}
  - name: SPRING_CONFIG_IMPORT
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: SPRING_CONFIG_IMPORT}}
  - name: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE}}
  - name: SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: KAFKA_BROKER}}
  - name: MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT
    ...
```
Most of these env vars follow the same pattern as every other service (active profile,
config-server address, Eureka address, OTLP endpoints). The one specific to
`accounts`:

- `SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS` ← `KAFKA_BROKER` - tells Spring Cloud Stream
  where to find the Kafka broker. `accounts` uses this to **publish** an event
  (`send-communication`) whenever a new account is created, which
  [`12_message.yml`](12_message.md) picks up to (pretend to) send a welcome email/SMS -
  `accounts` then **consumes** a reply event (`communication-sent`) back from `message` to
  mark the account as "notified." `loans` and `cards` don't have this Kafka wiring because
  their code doesn't publish or consume any events - only add it there if that code changes.

**Probes/Resources**: same shape as every business service - `/actuator/health/readiness`
and `/actuator/health/liveness` on port 8080 (its own app port, not a separate management
port), `250m/384Mi` requests, `500m/700Mi` limits. One difference: the `startupProbe` has
`failureThreshold: 60` instead of the usual `30`, so `accounts` gets up to 5 minutes
(60 × 5s) to boot rather than 2.5 - it has more to connect to on startup (config server,
Eureka, and Kafka).

## The Service

```yaml
type: LoadBalancer
ports:
  - port: 8080
    targetPort: 8080
```
Exposed externally so you can call `accounts` directly while testing, bypassing the gateway
and Keycloak auth. In a locked-down deployment you'd likely make this `ClusterIP` instead,
since normal traffic should always flow through the gateway (see
[13_gateway.md](13_gateway.md)), not straight to a business service.
