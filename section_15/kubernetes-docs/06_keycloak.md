# `06_keycloak.yml` - the login/identity server

Two objects: a **Deployment** (runs Keycloak) and a **Service**.

## What this is for

Keycloak issues and verifies login tokens (JWTs). Users log in against Keycloak; the
gateway ([`13_gateway.yml`](13_gateway.md)) then checks every incoming request's token
against Keycloak's public keys before letting it through to accounts/loans/cards.

## The Deployment

```yaml
containers:
  - name: keycloak
    image: quay.io/keycloak/keycloak:26.7.0
    args: ["start-dev"]
    env:
      - name: KC_BOOTSTRAP_ADMIN_USERNAME
        valueFrom:
          secretKeyRef:
            name: eazybank-secrets
            key: KC_BOOTSTRAP_ADMIN_USERNAME
      - name: KC_BOOTSTRAP_ADMIN_PASSWORD
        valueFrom:
          secretKeyRef:
            name: eazybank-secrets
            key: KC_BOOTSTRAP_ADMIN_PASSWORD
      - name: KC_HEALTH_ENABLED
        value: "true"
    ports:
      - name: http
        containerPort: 8080
      - name: management
        containerPort: 9000
```
- `args: ["start-dev"]` - runs Keycloak in **development mode**: no HTTPS requirement, less
  strict config validation, and it doesn't require a real production database. Good for
  learning/testing, not for a real deployment (real deployments use `start` with a proper
  database and TLS).
- The two `KC_BOOTSTRAP_ADMIN_*` variables come from the Secret in
  [`02_secrets.yml`](02_secrets.md) via `secretKeyRef` (same idea as `configMapKeyRef`, but
  pointed at a Secret instead of a ConfigMap) - these seed Keycloak's very first admin user
  the first time it starts up.
- `KC_HEALTH_ENABLED: "true"` - turns on Keycloak's built-in health check endpoints (used by
  the probes below). This is a literal `value:`, not pulled from the ConfigMap/Secret,
  because it's not something any other service needs to know or share.
- Two ports: `8080` is where Keycloak actually serves login pages and APIs; `9000` is a
  separate "management" port Keycloak exposes health/metrics endpoints on, kept apart from
  application traffic.

**Probes** all hit the *management* port (9000), using the paths Keycloak documents for
each check: `/health/started` (has it finished booting - used by `startupProbe`),
`/health/ready` (can it serve requests - `readinessProbe`), `/health/live` (is it still
alive/not stuck - `livenessProbe`).

**Resources**: Keycloak gets more than the plain microservices (`memory limit: 1Gi`) since
it's a heavier Java application with its own embedded database for dev mode.

**No persistent storage**: in dev mode, Keycloak's embedded database lives on the
container's own filesystem, so any realms, clients, or users you create are lost whenever
the pod restarts. That's fine for local testing and demos; you just recreate them, or the
bootstrap admin user is created again automatically on the next start. For data that
survives restarts, point Keycloak at a real database.

## The Service

```yaml
type: LoadBalancer
ports:
  - name: http
    port: 7080
    targetPort: 8080
```
`type: LoadBalancer` because people need to open Keycloak's login/admin UI from a browser
outside the cluster. Note `port: 7080` but `targetPort: 8080` - callers connect to
`keycloak:7080`, and the Service forwards that to port `8080` inside the container. This
lets you pick whatever external port number makes sense without touching the app itself.
