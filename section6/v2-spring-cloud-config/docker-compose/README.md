# docker-compose

Single Compose setup for the eazybank microservices (`configserver`, `accounts`, `loans`,
`cards`) and their RabbitMQ broker, parameterized so the same `docker-compose.yml` runs local,
qa, and prod by swapping the `--env-file` passed to `docker compose`.

## Layout

| File                 | Purpose                                                              |
|----------------------|-----------------------------------------------------------------------|
| `docker-compose.yml` | Service definitions for `rabbit`, `configserver`, `accounts`, `loans`, `cards`. |
| `common-config.yml`  | Shared `extends` targets: network, restart policy, resource limits, RabbitMQ/Config Server wiring. |
| `.env`               | Default variable values, loaded automatically for local/dev. Safe to commit. |
| `qa.env`             | Variable values for qa. fill in real credentials before use. |
| `prod.env`           | Variable values for prod. fill in real credentials before use. |

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
    environment:
      SPRING_RABBITMQ_HOST: "rabbit"
      SPRING_RABBITMQ_USERNAME: ${RABBITMQ_DEFAULT_USER:?set RABBITMQ_DEFAULT_USER in the env file}
      SPRING_RABBITMQ_PASSWORD: ${RABBITMQ_DEFAULT_PASS:?set RABBITMQ_DEFAULT_PASS in the env file}
```
The config every Spring Boot service (and `rabbit` itself) extends:
- `extends: network-deploy-service` — pulls in the `eazybank` network attachment above.
- `restart: unless-stopped` — a crashed container (OOM against the memory limit, a RabbitMQ
  blip) restarts on its own instead of staying down until someone notices.
- `deploy.resources.limits.memory: 700m` — caps each service's memory at 700 MB. Compose applies
  this even outside Swarm mode (unlike other `deploy` subkeys such as `replicas`).
- `SPRING_RABBITMQ_HOST` — hostname the JVM connects to; `rabbit` resolves via Docker's internal
  DNS to the `rabbit` service/container.
- `SPRING_RABBITMQ_USERNAME` / `PASSWORD` — read from `${RABBITMQ_DEFAULT_USER}` /
  `${RABBITMQ_DEFAULT_PASS}`, the same variables used to create the RabbitMQ user in the
  `rabbit` service. The `:?message` syntax makes `docker compose` **fail immediately** with that
  message if the variable isn't set in the active env file, instead of silently starting with
  an empty credential.

```yaml
  microservice-configserver-config:
    extends:
      service: microservice-base-config
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILE:-default}
      SPRING_CONFIG_IMPORT: configserver:http://configserver:8071/
```
Extra layer for services that also need Config Server (`accounts`, `loans`, `cards` — not
`configserver` itself, which has nothing to pull config *from*):
- `extends: microservice-base-config` — pulls in everything above (network, restart, memory
  limit, RabbitMQ credentials).
- `SPRING_PROFILES_ACTIVE` — which Spring profile the service boots with (`default`, `qa`,
  `prod`), read from `${SPRING_PROFILE}`; falls back to `default` if unset.
- `SPRING_CONFIG_IMPORT` — tells Spring Cloud Config where to pull configuration from at
  startup; always points at the `configserver` service on its internal port `8071`.

## `docker-compose.yml` explained

```yaml
name: eazybank-microservices
```
Sets a stable Compose project name, independent of the directory name. Keeps container/network
names (and thus `docker compose` commands) consistent no matter what the folder is called or
where it's checked out.

```yaml
  rabbit:
    image: rabbitmq:4-management
    ports:
      - "5672:5672"
      - "15672:15672"
```
RabbitMQ with the management plugin. `5672` is the AMQP port the Spring services connect to;
`15672` is the web management UI. Both are published to the host in every environment — see
[Notes](#notes) below.

```yaml
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER:?set RABBITMQ_DEFAULT_USER in the env file}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS:?set RABBITMQ_DEFAULT_PASS in the env file}
```
Creates the RabbitMQ user/password from the same env-file variables the Spring services use to
connect — one pair of credentials, sourced once, shared everywhere via `common-config.yml`.

```yaml
    deploy:
      resources:
        limits:
          memory: 512m
    healthcheck:
      test: rabbitmq-diagnostics check_port_connectivity
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 5s
```
Memory capped at 512 MB. Healthcheck polls RabbitMQ's own diagnostics every 10s (5s grace period
on startup, 10 retries before it's marked unhealthy) so dependents know when the broker is
actually ready to accept connections, not just when the container has started.

```yaml
    extends:
      file: common-config.yml
      service: microservice-base-config
```
Pulls in the network, `restart: unless-stopped`, and (redundantly, but harmlessly) the RabbitMQ
credential env vars from `common-config.yml`.

```yaml
  configserver:
    image: "eazybytes/configserver:${IMAGE_TAG:-s6}"
    container_name: configserver-ms
    ports:
      - "8071:8071"
    depends_on:
      rabbit:
        condition: service_healthy
```
- `${IMAGE_TAG:-s6}` — image tag comes from the env file, defaulting to `s6` if unset. This is
  what lets qa/prod pin a specific, validated build instead of always tracking whatever tag
  moves in local dev.
- `container_name` — fixed name per service (`configserver-ms`, etc.) rather than
  Compose's default `<project>-<service>-<n>`. Convenient for a single-host setup, but it means
  you can't run two copies of this stack (or `--scale`) on the same Docker host at once.
- `depends_on: rabbit: condition: service_healthy` — Compose won't start `configserver` until
  `rabbit`'s healthcheck reports healthy, not just "container started."

```yaml
    healthcheck:
      test: ["CMD", "bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8071 && printf 'GET /actuator/health/readiness HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3 && grep -q '\"status\":\"UP\"' <&3"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 10s
```
Opens a raw TCP connection to the container's own port `8071` (via `/dev/tcp`, since the base
image has no `curl`/`wget`), sends a bare HTTP GET for Spring Boot Actuator's readiness probe,
and checks the response contains `"status":"UP"`. 10s start-period grace, checked every 10s, 10
retries before unhealthy.

```yaml
    extends:
      file: common-config.yml
      service: microservice-base-config
```
Network, restart policy, memory limit, RabbitMQ credentials — but **not**
`microservice-configserver-config`, since `configserver` doesn't consume config from itself.

```yaml
  accounts:
    image: "eazybytes/accounts:${IMAGE_TAG:-s6}"
    container_name: accounts-ms
    ports:
      - "8080:8080"
    depends_on:
      configserver:
        condition: service_healthy
    extends:
      file: common-config.yml
      service: microservice-configserver-config
```
Same shape repeats for `accounts` (port `8080`), `loans` (port `8090`), and `cards` (port
`9000`): versioned image, fixed container name, host port mapping, wait for `configserver` to be
healthy before starting, and extend `microservice-configserver-config` for network / restart /
memory / RabbitMQ creds / Spring profile / config-import. None of these three currently declare
their own `healthcheck`, even though they expose the same Actuator endpoint `configserver` does
— see [Notes](#notes).

```yaml
networks:
  eazybank:
    driver: "bridge"
```
The single bridge network every service joins via `network-deploy-service`, giving them
DNS-based service discovery (`rabbit`, `configserver`, etc.) isolated from other Compose
projects on the same host.

## Environment files

Each env file supplies the same four variables; only the values differ.

| Variable               | `.env` (local)     | `qa.env`         | `prod.env`         |
|-------------------------|---------------------|-------------------|---------------------|
| `IMAGE_TAG`             | `s6`                | pin a tested tag  | pin a tested tag    |
| `SPRING_PROFILE`        | `default`           | `qa`              | `prod`              |
| `RABBITMQ_DEFAULT_USER` | `guest`             | real qa user      | real prod user      |
| `RABBITMQ_DEFAULT_PASS` | `guest`             | real qa password  | real prod password  |

`.env` is loaded automatically by `docker compose` whenever you run it from this directory, so
local/dev needs no extra flags. `qa.env` and `prod.env` must be passed explicitly with
`--env-file`; fill in real credentials before using them, and prefer sourcing those values from
a secrets manager / CI variable store rather than keeping a real `prod.env` on disk long-term.

## Commands

**Local / dev** (uses `.env` automatically):
```bash
docker compose up -d
```

**QA** — fill in real credentials in `qa.env` first, then:
```bash
docker compose --env-file qa.env -p eazybank-microservices-qa up -d
```

**Prod** — fill in real credentials in `prod.env` first, then:
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