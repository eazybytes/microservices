# `12_message.yml` - the messaging service

Just **one** object here - a Deployment. There's no Service, which is different from every
other business service in this app; here's why.

## What this is for

`message` listens for a Kafka event that `accounts` publishes when a new account is opened
(`send-communication`), pretends to send an email/SMS about it, and publishes a reply event
(`communication-sent`) that `accounts` consumes to mark the account as notified. See
[09_accounts.md](09_accounts.md) for the other half of that flow.

## Why there's no `containerPort`, no probes, and no Service

Every other business service declares a `containerPort` and has HTTP-based
`readinessProbe`/`livenessProbe`. This one doesn't, because `message` isn't treated as a web
service here: it doesn't serve requests, it only opens an outbound connection to Kafka to
consume and publish events. That means:
- There's nothing for a **Service** to route traffic *to* (a Service routes network
  requests to a port on a pod; there's no port here to route to).
- There's no HTTP endpoint for a **probe** to call. Kubernetes falls back to just watching
  whether the container process is alive - if it crashes, the Deployment restarts it, same
  as any container, just without the extra "is it actually healthy" layer probes add.

## The Deployment

```yaml
containers:
- name: message
  image: eazybytes/message:s14
  imagePullPolicy: Always
  env:
  - name: SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS
    valueFrom: {configMapKeyRef: {name: eazybank-configmap, key: KAFKA_BROKER}}
  resources:
    requests: {cpu: 250m, memory: 384Mi}
    limits: {cpu: 500m, memory: 700Mi}
```
Only one env var is needed: the Kafka broker address (same `KAFKA_BROKER` ConfigMap key that
`accounts` uses). Notice this service does **not** set
`SPRING_CONFIG_IMPORT` or `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` - unlike the other business
services, `message` doesn't register with Eureka or pull config from the config server; it's
a self-contained Kafka consumer/producer with everything it needs in its own bundled config.
Resources use the same standard allowance as the other business services.
