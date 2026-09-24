# `02_secrets.yml` - Keycloak admin credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: eazybank-secrets
  namespace: eazybank
  labels:
    app.kubernetes.io/part-of: eazybank
type: Opaque
stringData:
  KC_BOOTSTRAP_ADMIN_USERNAME: "admin"
  KC_BOOTSTRAP_ADMIN_PASSWORD: "admin"
```

## What this is for

A **Secret** holds sensitive values - passwords, tokens, keys - separately from your
Deployment YAML and from the container image. Here it holds the admin username/password
that [`06_keycloak.yml`](06_keycloak.md) uses to bootstrap Keycloak's first admin account.

## Field by field

- `kind: Secret` - marks this as a Secret object (as opposed to a plain ConfigMap).
- `metadata.name: eazybank-secrets` - other manifests reference this Secret by this exact
  name when they want to read a value out of it.
- `metadata.namespace: eazybank` - this Secret only exists inside, and is only usable by,
  pods in the `eazybank` namespace.
- `type: Opaque` - "Opaque" just means "generic key/value Secret, no special Kubernetes
  behavior attached." (Other types exist for things like TLS certs or Docker registry
  credentials, where Kubernetes understands the structure of the data.)
- `stringData` - a shortcut for writing Secret values in plain text in the YAML file;
  Kubernetes base64-encodes them for you when the object is created. (The alternative field,
  `data`, requires you to base64-encode the values yourself before writing them here.)

## How other manifests use this

In [`06_keycloak.yml`](06_keycloak.md), the container's env vars are filled in with:
```yaml
- name: KC_BOOTSTRAP_ADMIN_USERNAME
  valueFrom:
    secretKeyRef:
      name: eazybank-secrets
      key: KC_BOOTSTRAP_ADMIN_USERNAME
```
This means "read the key `KC_BOOTSTRAP_ADMIN_USERNAME` out of the Secret named
`eazybank-secrets`, and set it as this environment variable inside the container."

## Important caveat

Kubernetes Secrets are **base64-encoded, not encrypted**, by default. Anyone who can read
this Secret object (or this YAML file, since it's committed with `admin`/`admin` in plain
text) has the credential. That's fine for a local learning cluster, but before running this
for real you'd want a proper secrets manager - Sealed Secrets, External Secrets Operator, or
HashiCorp Vault - so the actual credential value never lives in a plain YAML file in git.
