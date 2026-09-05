# docker-compose

Single Compose setup for the eazybank microservices (`configserver`, `eurekaserver`, `accounts`,
`loans`, `cards`), parameterized so the same `docker-compose.yml` runs local, qa, and prod by
swapping the `--env-file` passed to `docker compose`.

## Layout

| File                 | Purpose                                                              |
|----------------------|-----------------------------------------------------------------------|
| `docker-compose.yml` | Service definitions for `configserver`, `eurekaserver`, `accounts`, `loans`, `cards`. |
| `common-config.yml`  | Shared `extends` targets: network, restart policy, resource limits, Config Server/Eureka wiring. |
| `.env`               | Default variable values, loaded automatically for local/dev. Safe to commit. |
| `qa.env`             | Template for qa values — copy and fill in real values, gitignored once real values are added. |
| `prod.env`           | Template for prod values — copy and fill in real values, gitignored once real values are added. |

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
The config every Spring Boot service extends:
- `extends: network-deploy-service` — pulls in the `eazybank` network attachment above.
- `restart: unless-stopped` — a crashed container (OOM against the memory limit, a transient
  dependency blip) restarts on its own instead of staying down until someone notices.
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
`cards` — not `configserver` itself, which has nothing to pull config *from*):
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
Top layer for services that register with and discover peers through Eureka (`accounts`, `loans`,
`cards` — not `eurekaserver` itself, which has nothing to register with):
- `extends: microservice-configserver-config` — pulls in everything above (network, restart,
  memory limit, Config Server import, active profile).
- `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` — the Eureka registry URL each client polls to register
  itself and discover other services; always points at the `eurekaserver` service on its internal
  port `8070`.

## `docker-compose.yml` explained

```yaml
name: eazybank-microservices
```
Sets a stable Compose project name, independent of the directory name. Keeps container/network
names (and thus `docker compose` commands) consistent no matter what the folder is called or
where it's checked out.

```yaml
  configserver:
    image: "eazybytes/configserver:${IMAGE_TAG:-s8}"
    container_name: configserver-ms
    ports:
      - "8071:8071"
```
- `${IMAGE_TAG:-s8}` — image tag comes from the env file, defaulting to `s8` if unset. This is
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
    extends:
      file: common-config.yml
      service: microservice-base-config
```
Opens a raw TCP connection to the container's own port `8071` (via `/dev/tcp`, since the base
image has no `curl`/`wget`), sends a bare HTTP GET for Spring Boot Actuator's readiness probe,
and checks the response contains `"status":"UP"`. 5s start-period grace, checked every 10s, 10
retries before unhealthy. `extends` pulls in network, restart policy, and memory limit from
`common-config.yml` — but **not** `microservice-configserver-config`, since `configserver`
doesn't consume config from itself.

```yaml
  eurekaserver:
    image: "eazybytes/eurekaserver:${IMAGE_TAG:-s8}"
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
The Eureka naming server that `accounts`, `loans`, and `cards` register with and use for
service discovery. Same healthcheck shape as `configserver`, just against its own port `8070`.
`depends_on: configserver: condition: service_healthy` means Compose won't start `eurekaserver`
until `configserver` is confirmed healthy. `extends: microservice-configserver-config` gives it
network, restart, memory limit, and Config Server import/profile — but not
`microservice-eureka-config`, since `eurekaserver` doesn't register with itself.

```yaml
  accounts:
    image: "eazybytes/accounts:${IMAGE_TAG:-s8}"
    container_name: accounts-ms
    ports:
      - "8080:8080"
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
`9000`): versioned image, fixed container name, host port mapping, wait for both `configserver`
and `eurekaserver` to be healthy before starting, and extend `microservice-eureka-config` for
network / restart / memory / Config Server import / active profile / Eureka registry URL. None
of these three currently declare their own `healthcheck`, even though they expose the same
Actuator endpoint `configserver` and `eurekaserver` do — see [Notes](#notes).

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

| Variable         | `.env` (local) | `qa.env` | `prod.env` |
|------------------|----------------|----------|------------|
| `IMAGE_TAG`      | `s8`           | pin a tested tag | pin a tested tag |
| `SPRING_PROFILE` | `default`      | `qa`     | `prod`     |

`.env` is loaded automatically by `docker compose` whenever you run it from this directory, so
local/dev needs no extra flags. `qa.env` and `prod.env` are checked in as templates — currently
neither variable is sensitive, but the in-file comments call for copying them and gitignoring the
copy once real values (credentials, hostnames, etc.) are added in later sections, and for
preferring a secrets manager / CI variable store over keeping a real `prod.env` on disk
long-term.

## Commands

**Local / dev** (uses `.env` automatically):
```bash
docker compose up -d
```

**QA** — fill in real values in `qa.env` first, then:
```bash
docker compose --env-file qa.env -p eazybank-microservices-qa up -d
```

**Prod** — fill in real values in `prod.env` first, then:
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

## Notes

- Only `configserver` and `eurekaserver` declare a `healthcheck`. `accounts`, `loans`, and
  `cards` don't, so `depends_on: condition: service_healthy` isn't available against them — any
  future service that needs to wait on one of these three can only use the default
  `condition: service_started`, which doesn't confirm the app has actually finished booting.
