# docker-compose

Single Compose setup for the eazybank microservices (`configserver`, `accounts`, `loans`,
`cards`) and one MySQL database per service (`accountsdb`, `loansdb`, `cardsdb`), parameterized
so the same `docker-compose.yml` runs local, qa, and prod by swapping the `--env-file` passed to
`docker compose`.

## Layout

| File                 | Purpose                                                              |
|----------------------|-----------------------------------------------------------------------|
| `docker-compose.yml` | Service definitions for `accountsdb`, `loansdb`, `cardsdb`, `configserver`, `accounts`, `loans`, `cards`. |
| `common-config.yml`  | Shared `extends` targets: network, restart policy, resource limits, MySQL/Config Server wiring. |
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
`extends`-ed by the fragments below — Compose's `extends` can only pull in one service at a time,
so this is the bottom of the chain.

```yaml
  microservice-db-config:
    extends:
      service: network-deploy-service
    image: mysql
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 350m
    healthcheck:
      test: [ "CMD", "mysqladmin", "ping", "-h", "localhost" ]
      timeout: 10s
      retries: 10
      interval: 10s
      start_period: 10s
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-root}
```
The config every MySQL container (`accountsdb`, `loansdb`, `cardsdb`) extends:
- `extends: network-deploy-service` — pulls in the `eazybank` network attachment above.
- `image: mysql` — same base image for all three databases; each service below only adds its own
  `container_name`, port mapping, volume, and `MYSQL_DATABASE`.
- `restart: unless-stopped` — a crashed/OOM'd container restarts on its own.
- `deploy.resources.limits.memory: 350m` — caps each database's memory at 350 MB.
- `healthcheck` — polls `mysqladmin ping` every 10s (10s start-period grace, 10 retries) so
  dependents know when MySQL is actually accepting connections, not just when the container has
  started.
- `MYSQL_ROOT_PASSWORD` — read from `${DB_PASSWORD}`, defaulting to `root` if unset. The same
  variable is reused as the Spring datasource password below, so app and database always agree.

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
- `extends: network-deploy-service` — pulls in the `eazybank` network attachment.
- `restart: unless-stopped` — restarts automatically on crash (e.g. hitting the memory limit).
- `deploy.resources.limits.memory: 700m` — caps each service's memory at 700 MB. Compose applies
  this even outside Swarm mode (unlike other `deploy` subkeys such as `replicas`).

```yaml
  microservice-configserver-config:
    extends:
      service: microservice-base-config
    environment:
      SPRING_CONFIG_IMPORT: configserver:http://configserver:8071/
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILE:-default}
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD:-root}
```
Extra layer for services that also need Config Server and a database (`accounts`, `loans`,
`cards` — not `configserver` itself, which has neither):
- `extends: microservice-base-config` — pulls in everything above (network, restart, memory
  limit).
- `SPRING_CONFIG_IMPORT` — tells Spring Cloud Config where to pull configuration from at startup;
  always points at the `configserver` service on its internal port `8071`.
- `SPRING_PROFILES_ACTIVE` — which Spring profile the service boots with (`default`, `qa`,
  `prod`), read from `${SPRING_PROFILE}`; falls back to `default` if unset.
- `SPRING_DATASOURCE_USERNAME` — hardcoded to `root` rather than parameterized; every service
  connects to its database as `root`.
- `SPRING_DATASOURCE_PASSWORD` — read from `${DB_PASSWORD}`, the same variable used to set
  `MYSQL_ROOT_PASSWORD` above, so app and database always agree.

## `docker-compose.yml` explained

```yaml
name: eazybank-microservices
```
Sets a stable Compose project name, independent of the directory name. Keeps container/network
names (and thus `docker compose` commands) consistent no matter what the folder is called or
where it's checked out.

```yaml
  accountsdb:
    container_name: accountsdb
    ports:
      - "3306:3306"
    volumes:
      - /Users/eazybytes/Desktop/accounts-data:/var/lib/mysql
    environment:
      MYSQL_DATABASE: accountsdb
    extends:
      file: common-config.yml
      service: microservice-db-config
```
One MySQL container per service — `accountsdb` (host port `3306`), `loansdb` (host port `3307`),
`cardsdb` (host port `3308`) — each mapping container port `3306` to a different host port so all
three can run side by side. Each mounts a host directory under `/Users/eazybytes/Desktop` to
`/var/lib/mysql` so data survives `docker compose down`, and sets its own `MYSQL_DATABASE` to
create that schema on first boot. All three extend `microservice-db-config` from
`common-config.yml` for the network, image, restart policy, memory limit, and root password. See
[Notes](#notes) for two rough edges in this block.

```yaml
  configserver:
    image: "eazybytes/configserver:${IMAGE_TAG:-s7}"
    container_name: configserver-ms
    ports:
      - "8071:8071"
```
- `${IMAGE_TAG:-s7}` — image tag comes from the env file, defaulting to `s7` if unset. This is
  what lets qa/prod pin a specific, validated build instead of always tracking whatever tag moves
  in local dev.
- `container_name` — fixed name per service (`configserver-ms`, etc.) rather than Compose's
  default `<project>-<service>-<n>`. Convenient for a single-host setup, but it means you can't
  run two copies of this stack (or `--scale`) on the same Docker host at once.

```yaml
    healthcheck:
      test: ["CMD", "bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8071 && printf 'GET /actuator/health/readiness HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3 && grep -q '\"status\":\"UP\"' <&3"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 5s
```
Opens a raw TCP connection to the container's own port `8071` (via `/dev/tcp`, since the base
image has no `curl`/`wget`), sends a bare HTTP GET for Spring Boot Actuator's readiness probe,
and checks the response contains `"status":"UP"`. 5s start-period grace, checked every 10s, 10
retries before unhealthy.

```yaml
    extends:
      file: common-config.yml
      service: microservice-base-config
```
Network, restart policy, memory limit — but **not** `microservice-configserver-config`, since
`configserver` doesn't consume config or a database of its own.

```yaml
  accounts:
    image: "eazybytes/accounts:${IMAGE_TAG:-s7}"
    container_name: accounts-ms
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: "jdbc:mysql://accountsdb:3306/accountsdb"
    depends_on:
      configserver:
        condition: service_healthy
      accountsdb:
        condition: service_healthy
    extends:
      file: common-config.yml
      service: microservice-configserver-config
```
Same shape repeats for `accounts` (port `8080`, backed by `accountsdb`), `loans` (port `8090`,
backed by `loansdb`), and `cards` (port `9000`, backed by `cardsdb`): versioned image, fixed
container name, host port mapping, a `SPRING_DATASOURCE_URL` pointing at its own database
container over the internal network, `depends_on` both `configserver` and its database with
`condition: service_healthy` (Compose won't start the service until both report healthy, not just
"container started"), and `extends: microservice-configserver-config` for network / restart /
memory / Spring profile / config-import / datasource credentials. None of these three declares
its own `healthcheck`, even though they expose the same Actuator endpoint `configserver` does —
see [Notes](#notes).

```yaml
networks:
  eazybank:
    driver: bridge
```
The single bridge network every service joins via `network-deploy-service`, giving them
DNS-based service discovery (`accountsdb`, `configserver`, etc.) isolated from other Compose
projects on the same host.

## Environment files

Each env file supplies the same three variables; only the values differ.

| Variable         | `.env` (local) | `qa.env`         | `prod.env`         |
|-------------------|-----------------|-------------------|---------------------|
| `IMAGE_TAG`       | `s7`            | pin a tested tag  | pin a tested tag    |
| `SPRING_PROFILE`  | `default`       | `qa`              | `prod`              |
| `DB_PASSWORD`     | `root`          | real qa password  | real prod password  |

`DB_PASSWORD` sets both `MYSQL_ROOT_PASSWORD` on each database container and
`SPRING_DATASOURCE_PASSWORD` on each Spring service, so app and database always agree.

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

**Check merged config** without starting anything (useful for verifying which values an env file
actually resolves to):
```bash
docker compose --env-file prod.env config
```

## Notes

A few rough edges as of this setup, worth knowing before relying on it:

- **Host ports are fixed, not environment-scoped.** `3306`/`3307`/`3308` (databases), `8071`
  (configserver), `8080`/`8090`/`9000` (accounts/loans/cards) are the same across local, qa, and
  prod. Running two of these environments on the same Docker host at once will collide on port
  binding even though `-p` keeps the containers/networks separate.
- **`accounts`, `loans`, and `cards` have no `healthcheck` of their own**, unlike `configserver`
  and the three database containers. Nothing currently waits on their readiness the way
  `depends_on: condition: service_healthy` does for the others.
- **Database volumes bind-mount a hardcoded host path** (`/Users/eazybytes/Desktop/*-data`).
  This only works on the machine (and user account) that path belongs to — it won't portably run
  on another host or in CI without editing `docker-compose.yml`. A named volume would avoid that.
- **`loansdb`'s `container_name` is `loanssdb`** (extra `s`), inconsistent with the service name
  `loansdb` and its sibling containers' naming (`accountsdb`, `cardsdb`).
- **`SPRING_DATASOURCE_USERNAME` is hardcoded to `root`** in `common-config.yml` rather than
  read from an env-file variable like the password is — every environment connects as `root`.
