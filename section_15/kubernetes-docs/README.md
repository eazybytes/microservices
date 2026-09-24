# EazyBank Kubernetes manifests, explained simply

This folder has one explainer file per manifest in [`../kubernetes`](../kubernetes). Each
one walks through the actual YAML and explains, in plain language, what every block is for.
It's written for someone who is comfortable reading YAML but new to Kubernetes concepts.

Read this page first - it explains the handful of Kubernetes ideas that show up in almost
every file, so the per-file docs don't have to repeat themselves.

## The building blocks you'll keep seeing

**Namespace** - a named "room" inside the cluster that groups resources together. Two
resources in different namespaces can have the same name without clashing. Almost every
resource in this app lives in the `eazybank` namespace (see [00_namespace.md](00_namespace.md)).

**Deployment** - tells Kubernetes "keep N copies of this container running at all times."
If a copy (a **Pod**) crashes, the Deployment starts a replacement automatically. It also
manages rolling updates when you change the image version. Every microservice in this app
(accounts, loans, cards, gatewayserver, etc.) is run as a Deployment with `replicas: 1`, so
right now there's no redundancy - a crashed pod is replaced, but there's no second copy
serving traffic while that happens.

Each Deployment is named `<component>-deployment` (`redis-deployment`, `kafka-deployment`,
`keycloak-deployment`, ...), while its Service uses the plain component name (`redis`,
`kafka`, `keycloak`). The Service name is what other pods use as a hostname, so it stays
short; the suffix just makes it obvious in `kubectl` output which object is the Deployment.

**Labels** - every object carries `app.kubernetes.io/part-of: eazybank`, and every
Deployment, its pods, and its Service also carry `app: <component>` and
`app.kubernetes.io/name: <component>`. The `app` label is the one that does real work: it's
what each Deployment's `selector.matchLabels` and each Service's `selector` match on. The
`app.kubernetes.io/*` labels are the standard recommended labels, handy for filtering, e.g.
`kubectl get all -n eazybank -l app.kubernetes.io/part-of=eazybank`.

**Pod template** (the `spec.template` block inside a Deployment) - the actual recipe for
one running copy: which container image, which ports, which environment variables. The
Deployment stamps out copies of this template.

**`imagePullPolicy: Always`** - the app images (`eazybytes/<service>:s14`) keep the same tag
every time they're rebuilt and pushed. For a tag like that, Kubernetes defaults to
`IfNotPresent`: if a node already has *an* image called `eazybytes/accounts:s14`, it reuses
that cached copy and never checks Docker Hub, so you keep running the old build. `Always`
makes the node check Docker Hub on every pod start and pull the image if it has changed.
After pushing a new image, `kubectl rollout restart deployment -n eazybank` picks it up.
The infrastructure images (Redis, Kafka, Keycloak, Grafana) use versioned tags that never
change, so they don't need this.

**Service** - a stable network name/address that routes traffic to whichever Pods currently
match its label selector. Pods come and go (they get new IP addresses every time), but a
Service's name and IP stay constant, so other components can always reach `accounts` or
`kafka` by name instead of tracking pod IPs. You'll see two `type`s here:
- `ClusterIP` (the default) - only reachable from *inside* the cluster. Used for anything
  that's a backend dependency for other pods, not something a person outside the cluster
  should hit directly (redis, kafka).
- `LoadBalancer` - additionally asks the cloud provider (or local cluster tool) to hand out
  an external IP, so something outside the cluster (your browser, Postman) can reach it too.

**ConfigMap** - a bag of non-secret key/value settings (URLs, hostnames, flags) that's kept
separate from the container image, so you can change config without rebuilding an image.
See [01_configmaps.md](01_configmaps.md) - almost every other manifest pulls values out of
the one ConfigMap defined there.

**Secret** - just like a ConfigMap, but for sensitive values (passwords, tokens). Kubernetes
stores Secret data base64-encoded, not encrypted - it's a way to *separate* sensitive values
from your manifests and control access to them via RBAC, not a substitute for a real secrets
manager. See [02_secrets.md](02_secrets.md).

**Environment variables via `valueFrom`** - instead of hardcoding a value in a Deployment,
most containers here pull it from the ConfigMap/Secret with:
```yaml
- name: SPRING_PROFILES_ACTIVE
  valueFrom:
    configMapKeyRef:
      name: eazybank-configmap
      key: SPRING_PROFILES_ACTIVE
```
This means "set the environment variable `SPRING_PROFILES_ACTIVE` inside the container to
whatever the key `SPRING_PROFILES_ACTIVE` currently holds in the `eazybank-configmap`
ConfigMap." `secretKeyRef` does the same thing but reads from a Secret.

**Probes** - how Kubernetes checks on a running container's health:
- `startupProbe` - "has this container finished booting yet?" Kubernetes keeps checking
  (up to `failureThreshold` times) before giving up and restarting it. This exists so slow
  starters (like Keycloak) get a long grace period without making the *other* probes equally
  slow to react once the app is actually up.
- `readinessProbe` - "is this container ready to receive traffic *right now*?" If this
  fails, Kubernetes stops sending it traffic via its Service, but does **not** restart it -
  it might just be busy or waiting on a dependency.
  It gets to try again.
- `livenessProbe` - "is this container still working, or is it stuck/deadlocked?" If this
  fails, Kubernetes kills and restarts the container.

Most services here check Spring Boot Actuator's `/actuator/health/readiness` and
`/actuator/health/liveness` endpoints - these come for free once `spring-boot-starter-actuator`
is on the classpath and Spring Boot detects it's running on Kubernetes.

**Resources (`requests`/`limits`)** - `requests` is what a container is guaranteed to get
(Kubernetes uses this to decide which node has room to schedule the pod); `limits` is the
hard ceiling - if a container tries to use more memory than its limit, it gets killed
(`OOMKilled`); more CPU than its limit just gets throttled, not killed.

**No persistent storage** - this setup is meant for local testing and demos, so nothing
here uses a PersistentVolumeClaim (PVC). Kafka, Grafana, and Keycloak all keep their data on
the container's own filesystem, which is wiped every time the pod is recreated. In a real
deployment you'd add PVCs (and typically run stateful components like Kafka as a
StatefulSet) so that data survives restarts - see [05_kafka.md](05_kafka.md).

## Files in this app, in the order they get applied

| # | Manifest | What it is |
|---|----------|-------------|
| 00 | [00_namespace.md](00_namespace.md) | Creates the `eazybank` namespace |
| 01 | [01_configmaps.md](01_configmaps.md) | Shared, non-secret configuration for every service |
| 02 | [02_secrets.md](02_secrets.md) | Keycloak admin credentials |
| 03 | [03_redis.md](03_redis.md) | Redis cache, used by the gateway |
| 04 | [04_grafana-lgtm.md](04_grafana-lgtm.md) | Observability stack (traces/logs/metrics + dashboards) |
| 05 | [05_kafka.md](05_kafka.md) | Kafka broker, for async messaging |
| 06 | [06_keycloak.md](06_keycloak.md) | Identity/login server |
| 07 | [07_configserver.md](07_configserver.md) | Central place all microservices load their config from |
| 08 | [08_eurekaserver.md](08_eurekaserver.md) | Service registry, so services can find each other by name |
| 09 | [09_accounts.md](09_accounts.md) | Accounts microservice |
| 10 | [10_loans.md](10_loans.md) | Loans microservice |
| 11 | [11_cards.md](11_cards.md) | Cards microservice |
| 12 | [12_message.md](12_message.md) | Sends email/SMS notifications, triggered via Kafka |
| 13 | [13_gateway.md](13_gateway.md) | Single entry point that routes and secures all incoming API traffic |

The numeric prefixes are just a hint for the order to `kubectl apply` things in (things that
other manifests depend on come first) - Kubernetes doesn't enforce this itself.
