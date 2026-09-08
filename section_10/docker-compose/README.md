# docker-compose

Single Compose setup for the eazybank microservices (`configserver`, `eurekaserver`, `accounts`,
`loans`, `cards`, `gatewayserver`) plus a `redis` cache they depend on, parameterized so the same
`docker-compose.yml` runs local, qa, and prod by swapping the `--env-file` passed to
`docker compose`.

## Layout

| File                 | Purpose                                                              |
|----------------------|-----------------------------------------------------------------------|
| `docker-compose.yml` | Service definitions for `redis`, `configserver`, `eurekaserver`, `accounts`, `loans`, `cards`, `gatewayserver`. |
| `common-config.yml`  | Shared `extends` targets: network, restart policy, resource limits, Config Server/Eureka wiring. |
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
    deploy:
      resources:
        limits:
          memory: 700m
```
The config every Spring Boot service extends, directly or indirectly:
- `extends: network-deploy-service` — pulls in the `eazybank` network attachment above.
- `restart: unless-stopped` — a crashed container (OOM against the memory limit, a slow
  dependency) restarts on its own instead of staying down until someone notices.
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
  configserver:
    image: "eazybytes/configserver:${IMAGE_TAG:-s10}"
    container_name: configserver-ms
    ports:
      - "8071:8071"
```
- `${IMAGE_TAG:-s10}` — image tag comes from the env file, defaulting to `s10` if unset. This is
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
    image: "eazybytes/eurekaserver:${IMAGE_TAG:-s10}"
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
    image: "eazybytes/accounts:${IMAGE_TAG:-s10}"
    container_name: accounts-ms
    ports:
        - "8080:8080"
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
Same shape repeats for `accounts` (port `8080`), `loans` (port `8090`), and `cards` (port
`9000`): versioned image, fixed container name, host port mapping, own readiness healthcheck,
waits for both `configserver` and `eurekaserver` to be healthy before starting, and extends
`microservice-eureka-config` for network / restart / memory / Spring profile / config-import /
Eureka registry URL.

```yaml
  gatewayserver:
    image: "eazybytes/gatewayserver:${IMAGE_TAG:-s10}"
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
    extends:
      file: common-config.yml
      service: microservice-eureka-config
```
The API gateway and single entry point into the stack (port `8072`). Waits for all three
downstream services (`accounts`, `loans`, `cards`) plus `redis` to report healthy before
starting, and extends `microservice-eureka-config` so it can route to the downstream services by
discovering their instances through Eureka rather than hardcoded hostnames. The `SPRING_DATA_REDIS_*`
variables point its rate limiter at the `redis` service on the internal network. Declares no
healthcheck of its own.

```yaml
networks:
  eazybank:
    driver: bridge
```
The single bridge network every service joins via `network-deploy-service`, giving them
DNS-based service discovery (`configserver`, `eurekaserver`, etc.) isolated from other Compose
projects on the same host.

## Environment files

Each env file supplies the same two variables; only the values differ.

| Variable         | `.env` (local) | `qa.env`         | `prod.env`         |
|-------------------|-----------------|-------------------|---------------------|
| `IMAGE_TAG`      | `s10`           | pin a tested tag  | pin a tested tag    |
| `SPRING_PROFILE` | `default`       | `qa`              | `prod`              |

`.env` is loaded automatically by `docker compose` whenever you run it from this directory, so
local/dev needs no extra flags. `qa.env` and `prod.env` must be passed explicitly with
`--env-file`; pin real, tested `IMAGE_TAG` values before using them rather than leaving them on
a moving tag.

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
