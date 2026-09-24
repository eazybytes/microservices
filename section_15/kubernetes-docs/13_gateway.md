# `13_gateway.yml` - the API gateway

Two objects: a **Deployment** and a **Service**.

## What this is for

The gateway is the single front door for the whole app. Instead of clients calling
`accounts`, `loans`, and `cards` directly, they call the gateway, which checks their login
token (via Keycloak), applies rate limiting (via Redis), and routes the request on to the
right backend service (looked up through Eureka). It's the last manifest applied because it
depends on almost everything else already existing: accounts/loans/cards to route to,
Eureka to find them, Keycloak to validate tokens against, and Redis for rate limiting.

## The Deployment

```yaml
containers:
- name: gatewayserver
  image: eazybytes/gatewayserver:s14
  ports:
  - containerPort: 8072
  env:
  - name: SPRING_PROFILES_ACTIVE ... SPRING_PROFILES_ACTIVE
  - name: SPRING_CONFIG_IMPORT ... SPRING_CONFIG_IMPORT
  - name: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE ... EUREKA_CLIENT_SERVICEURL_DEFAULTZONE
  - name: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI ... (same key)
  - name: SPRING_DATA_REDIS_HOST ... REDIS_HOST
  - name: SPRING_DATA_REDIS_PORT ... REDIS_PORT
  - name: MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT ... OTLP_TRACES_ENDPOINT
  - name: MANAGEMENT_OPENTELEMETRY_LOGGING_EXPORT_OTLP_ENDPOINT ... OTLP_LOGS_ENDPOINT
  - name: MANAGEMENT_OTLP_METRICS_EXPORT_URL ... OTLP_METRICS_ENDPOINT
```
The first three env vars are the same pattern every business service uses (profile, config
server, Eureka). Three are specific to the gateway:

- `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI` - Keycloak's public-key endpoint.
  The gateway uses this to check that a request's JWT (login token) was really signed by our
  Keycloak, and hasn't been tampered with, before letting the request through.
- `SPRING_DATA_REDIS_HOST` / `SPRING_DATA_REDIS_PORT` - where to find Redis
  ([03_redis.yml](03_redis.md)) for the rate limiter and health check.

The three `MANAGEMENT_*` variables send telemetry to Grafana-LGTM, same as every other
service.

**Probes**: same shape as every other business service - `startupProbe`/`readinessProbe` on
`GET /actuator/health/readiness`, `livenessProbe` on `GET /actuator/health/liveness`, all on
port 8072.

**Resources**: `250m/384Mi` requests, `500m/700Mi` limits - the standard allowance.

## The Service

```yaml
type: LoadBalancer
ports:
  - port: 8072
    targetPort: 8072
```
Unlike accounts/loans/cards/configserver/eurekaserver, this one *does* genuinely need to be
reachable from outside the cluster - it's the intended entry point for all real API traffic,
so `LoadBalancer` here (as opposed to `ClusterIP`) reflects an actual requirement, not just
developer convenience.
