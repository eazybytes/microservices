# `11_cards.yml` - the cards microservice

Two objects: a **Deployment** and a **Service**. Same structure again as
[`09_accounts.yml`](09_accounts.md) and [`10_loans.yml`](10_loans.md) - the three business
microservices are set up identically except for name, port, and (for accounts) the Kafka
wiring.

## What's different from `accounts`/`loans`

- `image: eazybytes/cards:s14`.
- Container port `9000` (Service also uses `port`/`targetPort: 9000`, reachable at
  `cards:9000`).
- Like `loans`, **no Kafka environment variable** - `cards`'s code doesn't publish or
  consume any events.

Everything else - config-server/Eureka wiring, OTLP env vars, `/actuator/health/*` probes
(on port 9000 here, `startupProbe` `failureThreshold: 30`), `250m/384Mi` → `500m/700Mi` resources, `LoadBalancer` Service - follows
the same reasoning as [09_accounts.md](09_accounts.md).
