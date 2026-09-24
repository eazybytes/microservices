# `00_namespace.yml` - the namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: eazybank
  labels:
    app.kubernetes.io/part-of: eazybank
```

## What this is for

A **Namespace** is a way to group related resources together inside a cluster, a bit like a
folder. Every other manifest in this app sets `metadata.namespace: eazybank`, which puts it
inside this "room." Two apps in two different namespaces can both have a Deployment called
`accounts` without conflicting.

If you never create a namespace, everything lands in a namespace called `default` - that
works, but on a shared cluster it means your resources are mixed in with everyone else's,
and there's no easy way to delete "just this app" or apply access rules to "just this app."

## Field by field

- `apiVersion: v1` - Namespace is a core Kubernetes object, so it uses the oldest/simplest
  API group, just `v1` (no group prefix).
- `kind: Namespace` - tells Kubernetes what kind of object this YAML describes.
- `metadata.name: eazybank` - the namespace's name. Every other manifest references this
  exact string in its own `metadata.namespace` field.
- `labels.app.kubernetes.io/part-of: eazybank` - a label is just a searchable tag. This one
  says "this belongs to the eazybank app" - handy if you ever run `kubectl get all -l
  app.kubernetes.io/part-of=eazybank`.

## Why it's applied first

Every other resource says `namespace: eazybank`. If the namespace doesn't exist yet,
creating those resources fails. That's why this file is numbered `00` - it needs to exist
before anything else is applied.
