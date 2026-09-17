# docker-compose

Single Compose setup for the eazybank microservices (`configserver`, `eurekaserver`, `accounts`,
`loans`, `cards`, `gatewayserver`) plus their supporting infrastructure — a `redis` cache, a
`keycloak` OAuth2/OIDC server securing the gateway, and a `grafana-lgtm` stack (Loki, Grafana,
Tempo, Mimir) collecting the traces/logs/metrics every Spring Boot service exports — parameterized
so the same `docker-compose.yml` runs local, qa, and prod by swapping the `--env-file` passed to
`docker compose`.

## Layout

| File                 | Purpose                                                              |
|----------------------|-----------------------------------------------------------------------|
| `docker-compose.yml` | Service definitions for `keycloak`, `redis`, `grafana-lgtm`, `configserver`, `eurekaserver`, `accounts`, `loans`, `cards`, `gatewayserver`. |
| `common-config.yml`  | Shared `extends` targets: network, restart policy, resource limits, OTLP telemetry export, Config Server/Eureka wiring. |
| `.env`               | Default variable values, loaded automatically for local/dev. Safe to commit. |
| `qa.env`             | Variable values for qa. Pin a tested `IMAGE_TAG` before use. |
| `prod.env`           | Variable values for prod. Pin a tested `IMAGE_TAG` before use. |

## `common-config.yml` explained

```yaml
services:
  network-deploy-service:
    networks:
      - eazybank
```
A base fragment that just attaches a service to the `eazybank` network. It exists only to be
`extends`-ed by the fragment below — Compose's `extends` can only pull in one service at a time,
so this is the bottom of the chain.

```yaml
  microservice-base-config:
    extends:
      service: network-deploy-service
    restart: unless-stopped
    environment:
      MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT: http://grafana-lgtm:4318/v1/traces
      MANAGEMENT_OPENTELEMETRY_LOGGING_EXPORT_OTLP_ENDPOINT: http://grafana-lgtm:4318/v1/logs
      MANAGEMENT_OTLP_METRICS_EXPORT_URL: http://grafana-lgtm:4318/v1/metrics
    deploy:
      resources:
        limits:
          memory: 700m
```
The config every Spring Boot service extends, directly or indirectly:
- `extends: network-deploy-service` — pulls in the `eazybank` network attachment above.
- `restart: unless-stopped` — a crashed container (OOM against the memory limit, a slow
  dependency) restarts on its own instead of staying down until someone notices.
- `MANAGEMENT_OPENTELEMETRY_*` / `MANAGEMENT_OTLP_METRICS_EXPORT_URL` — points each service's
  traces, logs, and metrics at the `grafana-lgtm` service's OTLP HTTP endpoint (port `4318`) so
  they show up in Grafana without per-service config.
- `deploy.resources.limits.memory: 700m` — caps each service's memory at 700 MB. Compose applies
  this even outside Swarm mode (unlike other `deploy` subkeys such as `replicas`).

```yaml
  microservice-configserver-config:
    extends:
      service: microservice-base-config
    environment:
      SPRING_CONFIG_IMPORT: configserver:http://configserver:8071/
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILE:-default}
```
Extra layer for services that also need Config Server (`eurekaserver`, `accounts`, `loans`,
`cards`, `gatewayserver` — not `configserver` itself, which has nothing to pull config *from*):
- `extends: microservice-base-config` — pulls in everything above (network, restart, memory
  limit).
- `SPRING_CONFIG_IMPORT` — tells Spring Cloud Config where to pull configuration from at
  startup; always points at the `configserver` service on its internal port `8071`.
- `SPRING_PROFILES_ACTIVE` — which Spring profile the service boots with (`default`, `qa`,
  `prod`), read from `${SPRING_PROFILE}`; falls back to `default` if unset.

```yaml
  microservice-eureka-config:
    extends:
      service: microservice-configserver-config
    environment:
      EUREKA_CLIENT_SERVICEURL_DEFAULTZONE: http://eurekaserver:8070/eureka/
```
Extra layer for services that also need to register with / discover other services through
Eureka (`accounts`, `loans`, `cards`, `gatewayserver` — not `eurekaserver` itself, since a
discovery server doesn't register with itself, and not `configserver`, which nothing needs to
discover):
- `extends: microservice-configserver-config` — pulls in everything above (network, restart,
  memory limit, config import, Spring profile).
- `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` — the Eureka client's registry endpoint, pointing at
  the `eurekaserver` service's internal port `8070`.

## `docker-compose.yml` explained

```yaml
name: eazybank-microservices
```
Sets a stable Compose project name, independent of the directory name. Keeps container/network
names (and thus `docker compose` commands) consistent no matter what the folder is called or
where it's checked out.

```yaml
  keycloak:
    image: quay.io/keycloak/keycloak:26.7.3
    container_name: keycloak
    ports:
      - "127.0.0.1:7080:8080"
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: "${KEYCLOAK_ADMIN:-admin}"
      KC_BOOTSTRAP_ADMIN_PASSWORD: "${KEYCLOAK_ADMIN_PASSWORD:-admin}"
    volumes:
      - keycloak_data:/opt/keycloak/data
    command: "start-dev"
    extends:
      file: common-config.yml
      service: network-deploy-service
```
The OAuth2/OIDC server `gatewayserver` validates JWTs against. Runs Keycloak's `start-dev` mode
(not for production use as-is — it uses an embedded H2-backed store rather than an external DB).
- `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` — admin console credentials, read
  from `${KEYCLOAK_ADMIN}` / `${KEYCLOAK_ADMIN_PASSWORD}` and defaulting to `admin`/`admin` if
  unset. Neither is currently set in `.env`, `qa.env`, or `prod.env`, so every environment gets
  the default unless you add them.
- `ports: "127.0.0.1:7080:8080"` — bound to loopback only, unlike every other host port mapping
  in this file, so the admin console isn't reachable from outside the host.
- `volumes: keycloak_data:/opt/keycloak/data` — persists realm/user data in a named volume across
  container restarts.
- Extends `network-deploy-service` directly (like `redis` below), so it joins the `eazybank`
  network but doesn't get the `unless-stopped` restart policy, the memory limit, or the OTLP
  telemetry env vars applied to the Spring Boot services.

```yaml
  redis:
    image: redis
    ports:
      - "6379:6379"
    healthcheck:
      test: [ "CMD-SHELL", "redis-cli ping | grep PONG" ]
      timeout: 10s
      retries: 10
    extends:
      file: common-config.yml
      service: network-deploy-service
```
The cache `gatewayserver` uses (for its rate limiter). Untagged upstream `redis` image, exposed
on the host at `6379` mainly for local inspection. Healthcheck shells out to `redis-cli ping` and
checks for `PONG`. Note it extends `network-deploy-service` directly rather than
`microservice-base-config` — it joins the `eazybank` network but does **not** get the
`unless-stopped` restart policy or the 700m memory limit applied to the Spring Boot services.

```yaml
  grafana-lgtm:
    image: 'grafana/otel-lgtm'
    container_name: grafana-lgtm-ms
    ports:
      - '3000:3000'
      - '4317:4317'
      - '4318:4318'
    volumes:
      - grafana-lgtm-data:/data
    extends:
      file: common-config.yml
      service: network-deploy-service
```
The observability backend: Grafana's bundled Loki (logs) + Grafana (dashboards) + Tempo (traces)
+ Mimir/Prometheus (metrics) image, receiving everything the Spring Boot services push via
`MANAGEMENT_OPENTELEMETRY_*`/`MANAGEMENT_OTLP_METRICS_EXPORT_URL` (see `common-config.yml`
above).
- Port `3000` — the Grafana UI.
- Ports `4317`/`4318` — OTLP receivers over gRPC and HTTP respectively; only `4318` (HTTP) is
  actually used by the other services' OTLP endpoints.
- `volumes: grafana-lgtm-data:/data` — persists dashboards/metrics/traces across restarts.
- Like `keycloak` and `redis`, extends `network-deploy-service` directly, not
  `microservice-base-config` — no restart policy, memory limit, or (usefully, since it'd be
  circular) OTLP export env vars of its own.

```yaml
  configserver:
    image: "eazybytes/configserver:${IMAGE_TAG:-s12}"
    container_name: configserver-ms
    ports:
      - "8071:8071"
```
- `${IMAGE_TAG:-s12}` — image tag comes from the env file, defaulting to `s12` if unset. This is
  what lets qa/prod pin a specific, validated build instead of always tracking whatever tag
  moves in local dev.
- `container_name` — fixed name per service (`configserver-ms`, etc.) rather than
  Compose's default `<project>-<service>-<n>`. Convenient for a single-host setup, but it means
  you can't run two copies of this stack (or `--scale`) on the same Docker host at once.

```yaml
    healthcheck:
      test: ["CMD", "bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8071 && printf 'GET /actuator/health/readiness HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3 && grep -q '\"status\":\"UP\"' <&3"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 5s
```
Opens a raw TCP connection to the container's own port (via `/dev/tcp`, since the base image has
no `curl`/`wget`), sends a bare HTTP GET for Spring Boot Actuator's readiness probe, and checks
the response contains `"status":"UP"`. This same pattern (only the port differs) is reused for
every service's healthcheck below.

```yaml
    extends:
      file: common-config.yml
      service: microservice-base-config
```
Network, restart policy, and memory limit — but **not** `microservice-configserver-config`,
since `configserver` doesn't consume config from itself.

```yaml
  eurekaserver:
    image: "eazybytes/eurekaserver:${IMAGE_TAG:-s12}"
    container_name: eurekaserver-ms
    ports:
      - "8070:8070"
    depends_on:
      configserver:
        condition: service_healthy
    healthcheck:
      test: [ "CMD", "bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8070 && printf 'GET /actuator/health/readiness HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3 && grep -q '\"status\":\"UP\"' <&3" ]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 5s
    extends:
      file: common-config.yml
      service: microservice-configserver-config
```
The Eureka discovery server. `depends_on: configserver: condition: service_healthy` — Compose
won't start it until `configserver` reports healthy, since it pulls its own config at startup.
Extends `microservice-configserver-config` (network, restart, memory, config import, Spring
profile) rather than `microservice-eureka-config`, since it has no need to register itself with
its own registry.

```yaml
  accounts:
    image: "eazybytes/accounts:${IMAGE_TAG:-s12}"
    container_name: accounts-ms
    healthcheck:
      test: [ "CMD", "bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8080 && printf 'GET /actuator/health/readiness HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3 && grep -q '\"status\":\"UP\"' <&3" ]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 5s
    depends_on:
      configserver:
        condition: service_healthy
      eurekaserver:
        condition: service_healthy
    extends:
      file: common-config.yml
      service: microservice-eureka-config
```
Same shape repeats for `accounts` (originally port `8080`), `loans` (`8090`), and `cards`
(`9000`): versioned image, fixed container name, own readiness healthcheck, waits for both
`configserver` and `eurekaserver` to be healthy before starting, and extends
`microservice-eureka-config` for network / restart / memory / OTLP export / Spring profile /
config-import / Eureka registry URL. None of the three publishes a host port anymore — they're
reachable only over the `eazybank` network, routed to by `gatewayserver` via Eureka service
discovery rather than a fixed hostname:port.

```yaml
  gatewayserver:
    image: "eazybytes/gatewayserver:${IMAGE_TAG:-s12}"
    container_name: gatewayserver-ms
    ports:
      - "8072:8072"
    depends_on:
      accounts:
        condition: service_healthy
      loans:
        condition: service_healthy
      cards:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      SPRING_DATA_REDIS_CONNECT-TIMEOUT: 2s
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
      SPRING_DATA_REDIS_TIMEOUT: 1s
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI: "http://keycloak:8080/realms/master/protocol/openid-connect/certs"
    extends:
      file: common-config.yml
      service: microservice-eureka-config
```
The API gateway and single entry point into the stack (port `8072`) — and now the only service
in the stack that publishes a port other than `configserver`/`eurekaserver` (kept open for direct
inspection) and `keycloak`. Waits for all three downstream services (`accounts`, `loans`,
`cards`) plus `redis` to report healthy before starting, and extends
`microservice-eureka-config` so it can route to the downstream services by discovering their
instances through Eureka rather than hardcoded hostnames.
- `SPRING_DATA_REDIS_*` — point its rate limiter at the `redis` service on the internal network.
- `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK-SET-URI` — the JWK set the gateway's Spring
  Security OAuth2 resource server uses to validate incoming JWTs, pointing at the `keycloak`
  service's `master` realm over the internal network (not the host-mapped `7080` port).

Declares no healthcheck of its own.

```yaml
networks:
  eazybank:
    driver: bridge
```
The single bridge network every service joins via `network-deploy-service`, giving them
DNS-based service discovery (`configserver`, `eurekaserver`, etc.) isolated from other Compose
projects on the same host.

```yaml
volumes:
  grafana-lgtm-data:
  keycloak_data:
```
Named volumes backing `grafana-lgtm` (dashboards, metrics, traces, logs) and `keycloak` (realm,
user, and client data) so that data survives `docker compose down` / container recreation. Not
used by `redis` or any of the Spring Boot services, which are stateless.

## Environment files

Each env file supplies the same two variables; only the values differ.

| Variable         | `.env` (local) | `qa.env`         | `prod.env`         |
|-------------------|-----------------|-------------------|---------------------|
| `IMAGE_TAG`      | `s12`           | pin a tested tag  | pin a tested tag    |
| `SPRING_PROFILE` | `default`       | `qa`              | `prod`              |

`.env` is loaded automatically by `docker compose` whenever you run it from this directory, so
local/dev needs no extra flags. `qa.env` and `prod.env` must be passed explicitly with
`--env-file`; pin real, tested `IMAGE_TAG` values before using them rather than leaving them on
a moving tag.

`docker-compose.yml` also reads `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` for the Keycloak
admin console, but none of the env files set them, so every environment currently falls back to
the `admin`/`admin` default baked into the compose file — add them to `qa.env`/`prod.env` (or
inject from a secrets manager) before using Keycloak outside local/dev.

## Commands

**Local / dev** (uses `.env` automatically):
```bash
docker compose up -d
```

**QA** — pin the real `IMAGE_TAG` in `qa.env` first, then:
```bash
docker compose --env-file qa.env -p eazybank-microservices-qa up -d
```

**Prod** — pin the real `IMAGE_TAG` in `prod.env` first, then:
```bash
docker compose --env-file prod.env -p eazybank-microservices-prod up -d
```

The `-p` flag namespaces the project (containers, network, volumes) separately per environment,
so qa and prod don't collide if they're ever run on the same host. Omit it and everything falls
back to the `name: eazybank-microservices` set in `docker-compose.yml`.

**Tear down** (any environment — match the `--env-file`/`-p` used to bring it up):
```bash
docker compose --env-file qa.env -p eazybank-microservices-qa down
```

**Check merged config** without starting anything (useful for verifying which values an env
file actually resolves to):
```bash
docker compose --env-file prod.env config
```
