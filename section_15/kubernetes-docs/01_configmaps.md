# `01_configmaps.yml` - shared configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eazybank-configmap
  namespace: eazybank
  labels:
    app.kubernetes.io/part-of: eazybank
data:
  SPRING_PROFILES_ACTIVE: "prod"
  SPRING_CONFIG_IMPORT: "configserver:http://configserver:8071/"
  EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: "http://eurekaserver:8070/eureka/"
  SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI: "http://keycloak:7080/realms/master/protocol/openid-connect/certs"
  KAFKA_BROKER: "kafka:9092"
  REDIS_HOST: "redis"
  REDIS_PORT: "6379"
  OTLP_TRACES_ENDPOINT: "http://grafana-lgtm:4318/v1/traces"
  OTLP_LOGS_ENDPOINT: "http://grafana-lgtm:4318/v1/logs"
  OTLP_METRICS_ENDPOINT: "http://grafana-lgtm:4318/v1/metrics"
```

## What this is for

A **ConfigMap** is a bag of key/value settings that live outside the container image, so you
can change configuration (URLs, hostnames, feature flags) without rebuilding or
re-pushing an image. Almost every other Deployment in this app pulls one or more values out
of this single ConfigMap, named `eazybank-configmap`.

Think of this file as the one place you'd look to answer "what URL does `accounts` use to
reach the config server?" or "what Kafka broker address does everything point at?"

## Every key, explained

- `SPRING_PROFILES_ACTIVE: "prod"` - tells each Spring Boot app which configuration profile
  to run under (affects which `*-prod.yml` config it loads from the config server).
- `SPRING_CONFIG_IMPORT: "configserver:http://configserver:8071/"` - tells each Spring Boot
  app "go fetch your configuration from the Config Server at this address" instead of only
  using what's baked into the jar.
- `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: "http://eurekaserver:8070/eureka/"` - the address
  of the service registry (Eureka) that every microservice registers itself with, and looks
  other services up in.
- `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI` - the URL the gateway calls to
  fetch Keycloak's public keys, so it can verify that an incoming request's JWT (login token)
  was really signed by our Keycloak instance.
- `KAFKA_BROKER: "kafka:9092"` - the address of the Kafka broker. `accounts` and `message`
  read this to know where to publish/consume events.
- `REDIS_HOST` / `REDIS_PORT` - where the gateway finds Redis (used for its rate limiter and
  reported in its health check).
- `OTLP_TRACES_ENDPOINT`, `OTLP_LOGS_ENDPOINT`, `OTLP_METRICS_ENDPOINT` - where every service
  sends its traces/logs/metrics for the Grafana-LGTM observability stack to pick up. All
  three use port `4318` (OTLP over HTTP) on the `grafana-lgtm` Service.

There is no application-name key here: each service's `spring.application.name` is baked
into its own jar, so the manifests don't set `SPRING_APPLICATION_NAME` at all.

## How other manifests use this

Every service pulls specific keys out of this ConfigMap by name, e.g. in `09_accounts.yml`:
```yaml
- name: SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS
  valueFrom:
    configMapKeyRef:
      name: eazybank-configmap
      key: KAFKA_BROKER
```
This reads "set the container's `SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS` environment
variable to whatever's currently stored under the `KAFKA_BROKER` key in `eazybank-configmap`."
Note the environment variable name the container expects and the ConfigMap key name don't
have to match - here they don't (`KAFKA_BROKER` → `SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS`).

## Why ConfigMap and not Secret?

None of these values are sensitive - they're URLs and service names, not credentials. That's
exactly the line between the two: if leaking a value in `kubectl describe configmap` output
or in git would matter, it belongs in a Secret ([`02_secrets.yml`](02_secrets.md)) instead.
