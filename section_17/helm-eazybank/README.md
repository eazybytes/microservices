# eazybank-platform (modular Helm chart set)

Helm charts for the eazybank microservices platform, built as a
library chart + subcharts:

- `eazybank-common` is a **library chart**: it holds the shared
  Deployment/Service/ConfigMap/label templates and can't be installed on its
  own (`Error: library charts are not installable`).
- Each microservice has its own small chart under `eazybank-services/`. It
  fails with a clear message if you try to install it without the platform
  chart, instead of rendering broken resources.
- `eazybank-platform` is the umbrella chart you actually install. One
  `helm install` deploys the infra (Redis, Kafka, Keycloak, Grafana LGTM) and
  all 7 services. Environments are thin `values/values-{qa,prod}.yaml`
  overlays on top of it, not separate charts.

## Layout

```
eazybank-common/            # type: library - NOT installable on its own
  templates/
    _deployment.tpl           # defines "eazybank.deployment"
    _service.tpl               # defines "eazybank.service"
    _configmap.tpl               # defines "eazybank.configmap"
    _labels.tpl                   # defines "eazybank.commonLabels" / "eazybank.labels" / "eazybank.podLabels"

eazybank-services/           # one small chart per microservice
  accounts/  loans/  cards/  configserver/  discoveryserver/  gatewayserver/  message/
    Chart.yaml                # depends on eazybank-common (file://../../eazybank-common)
    values.yaml                 # this service's own defaults (image, resources, probe, which env vars it needs)
    templates/
      deployment.yaml             # {{ include "eazybank.deployment" . }}
      service.yaml                 # {{ include "eazybank.service" . }}  (message has no Service - no HTTP surface)
      rbac.yaml                    # discoveryserver only: ServiceAccount + Role + RoleBinding

eazybank-platform/           # top-level umbrella - the chart you actually install
  Chart.yaml                  # depends on eazybank-common + all 7 service charts
  values.yaml                  # global.* (propagates to every dependency) + infra (redis/kafka/keycloak/grafana-lgtm)
  values/
    values-qa.yaml               # namespace: eazybank-qa,   profile: qa
    values-prod.yaml              # namespace: eazybank-prod, profile: prod, scaled replicas
  templates/                  # numeric prefixes are for readability only - Helm orders resources by kind, not filename
    00-namespace.yaml
    01-secrets.yaml
    02-configmap.yaml            # {{ include "eazybank.configmap" . }} - same library template the services read from
    03-redis.yaml
    04-grafana-lgtm.yaml
    05-kafka.yaml
    06-keycloak.yaml
```

## How the pieces fit together

- `global.*` in `eazybank-platform/values.yaml` (namespace, `partOf` label,
  ConfigMap name, Spring profile, config-import/discovery-server/JWK URLs,
  Kafka/Redis/OTLP endpoints) is propagated by Helm
  automatically to every dependency chart - `eazybank-common` and all 7
  `eazybank-services/*` charts read `.Values.global.*` directly. This is the
  single source of truth; nothing below it repeats these values.
- To override one service's own settings (image tag, replica count, resource
  limits, probe timing), nest values under that service's dependency name in
  `eazybank-platform/values.yaml` or a `values/values-*.yaml` overlay - e.g.
  `values/values-prod.yaml` sets `accounts: {replicaCount: 2, startupProbe:
  {failureThreshold: 60}}`. Anything not overridden falls through to that
  service chart's own `values.yaml` defaults.
- `eazybank-common`'s three named templates are the only place the actual
  Deployment/Service/ConfigMap shape is defined. Every service's
  `templates/deployment.yaml` is one line: `{{ include "eazybank.deployment"
  . }}`. Per-service differences live in that service's own `values.yaml`
  and are read by `_deployment.tpl`: which env vars it gets is set by boolean
  flags (`profileEnabled`, `configImportEnabled`, `discoveryEnabled`,
  `jwkEnabled`, `redisEnabled`, `kafkaEnabled`, `otelEnabled`), and whether
  it has an HTTP port at all is set by `containerPort`. `message` leaves
  `containerPort` unset, so its Deployment gets no ports and no probes.

## Service discovery

Eureka has been replaced by the
[Spring Cloud Kubernetes Discovery Server](https://docs.spring.io/spring-cloud-kubernetes/reference/spring-cloud-kubernetes-discoveryserver.html)
(`eazybank-services/discoveryserver`, image
`springcloud/spring-cloud-kubernetes-discoveryserver`). Services don't register
with it. It reads Pods/Services/Endpoints from the Kubernetes API through the
`spring-cloud-kubernetes-discoveryserver` ServiceAccount (read-only `Role`
scoped to the release namespace) and serves them over HTTP on
`spring-cloud-kubernetes-discoveryserver:80`.

Services with `discoveryEnabled: true` (accounts, loans, cards, gatewayserver)
get `SPRING_CLOUD_KUBERNETES_DISCOVERY_DISCOVERY_SERVER_URL` from
`global.discoveryServerUrl`. For that to work, their images must be built with
`spring-cloud-starter-kubernetes-discoveryclient` instead of the Eureka client.
Service IDs are the Kubernetes Service names (`accounts`, `loans`, `cards`),
so Gateway routes must use `lb://accounts` and so on.

## External access (no Ingress)

No Ingress resource or ingress controller is used. Exactly three Services
are exposed with `type: LoadBalancer`; everything else is `ClusterIP`:

| Service | Port | Controlled by |
|---|---|---|
| `gatewayserver` | 8072 | `gatewayserver.service.type` (default in `eazybank-services/gatewayserver/values.yaml`) |
| `keycloak` | 7080 | `keycloak.service.type` in `eazybank-platform/values.yaml` |
| `grafana-lgtm` | 3000 (UI), 4317/4318 (OTLP) | `grafanaLgtm.service.type` in `eazybank-platform/values.yaml` |

The infra resources (Redis, Kafka, Keycloak, Grafana LGTM) match the plain
Kubernetes manifests from the previous section field for field; Helm only adds
its standard labels. Like those manifests, Kafka and Grafana keep their data
in the container filesystem, so it's lost when their pod restarts.

Get the external addresses with `kubectl get svc -n <namespace>` (the
`EXTERNAL-IP` column). On Docker Desktop, LoadBalancer Services bind to
`localhost` on the Service port - so only one environment at a time can hold
8072/7080/3000/4317/4318 there; a second release's LoadBalancers will stay `<pending>`.
When that second release is uninstalled, its pending LoadBalancer Services
keep the `service.kubernetes.io/load-balancer-cleanup` finalizer, so the
namespace hangs in `Terminating`. Clear it per Service with
`kubectl patch svc <name> -n <namespace> --type=merge -p '{"metadata":{"finalizers":null}}'`.

## Usage

Dependencies are already built into each chart's `charts/` folder (vendored
`.tgz`s + `Chart.lock`), so a fresh clone can `helm install` straight away.
If you ever edit a service chart's `Chart.yaml` or `eazybank-common` itself,
rebuild dependencies for every chart that depends on it:
```
for d in eazybank-services/*/ eazybank-platform; do
  (cd "$d" && helm dependency build .)
done
```

Install the default environment (namespace `eazybank`, Spring profile
`default`):
```
cd eazybank-platform
helm install eazybank .
```
The chart creates the `eazybank` namespace itself (`namespace.create: true`)
and puts every resource there, but the release record lives in the
namespace Helm ran against (`default` here). Use `helm list -A` to see it.

Install qa / prod. Each gets its own release and namespace, so they can run
side by side:
```
helm install eazybank-qa   . -f values/values-qa.yaml   --namespace eazybank-qa   --create-namespace
helm install eazybank-prod . -f values/values-prod.yaml --namespace eazybank-prod --create-namespace
```
Both overlays currently set `namespace.create: true`, so the namespace is
created twice: once by `--create-namespace` and once by the chart's own
`Namespace` resource. Helm 3 fails with
`namespaces "eazybank-qa" already exists`. Helm 4 takes ownership of the
namespace instead, so `helm uninstall` deletes the namespace too. To leave
the namespace in place after uninstall (or to use Helm 3), set
`namespace.create: false` in the overlay.

Internal Service names (`configserver`, `kafka`, `redis`, ...) are the same
in every environment. That's safe because DNS lookups resolve within the
pod's own namespace first. See "External access" above for the LoadBalancer
port caveat when running more than one environment on a local cluster.

Other common commands (run from `eazybank-platform/`):
```
helm template eazybank-qa . -f values/values-qa.yaml                  # render locally
helm install  eazybank-qa . -f values/values-qa.yaml -n eazybank-qa --create-namespace --dry-run=server
helm upgrade  eazybank-qa . -f values/values-qa.yaml -n eazybank-qa
helm uninstall eazybank-qa -n eazybank-qa
```

## Known limitation

Every `repository:` in every `Chart.yaml` here is `file://../relative/path`.
That only resolves against this exact local checkout layout - packaging any
of these charts for a real chart repository or OCI registry (`helm push`)
would require re-pointing those dependencies first. For a single-repo,
single-team setup like this one that's a reasonable tradeoff; for a chart set
meant to be independently published and versioned, it isn't.
