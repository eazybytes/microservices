# `10_loans.yml` - the loans microservice

Two objects: a **Deployment** and a **Service**. This file is structurally identical to
[`09_accounts.yml`](09_accounts.md) and [`11_cards.yml`](11_cards.md) - same pattern of env
vars, probes, and resources - just running the loans business logic instead.

## What's different from `accounts`

- `image: eazybytes/loans:s14` instead of `eazybytes/accounts:s14`.
- Container port `8090` instead of `8080` (and the Service's `port`/`targetPort` match, so
  it's reachable at `loans:8090`).
- **No Kafka environment variable.** `loans`'s code doesn't publish or consume any Kafka
  events, so there's nothing to wire `SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS` to. If a
  future feature needs loans to publish events too, that's the line to add (copy the
  `SPRING_CLOUD_STREAM_KAFKA_BINDER_BROKERS` block from `09_accounts.yml`).

Everything else - the `SPRING_PROFILES_ACTIVE`/`SPRING_CONFIG_IMPORT`/
`EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` wiring, the OTLP env vars, the
`startupProbe`/`readinessProbe`/`livenessProbe` hitting `/actuator/health/*` (on port 8090
here, with the standard `startupProbe` `failureThreshold: 30` rather than accounts' `60`), the `250m/384Mi` → `500m/700Mi` resources, and the `LoadBalancer` Service - is the
same reasoning as [09_accounts.md](09_accounts.md); see that file for the explanation of
each one.
