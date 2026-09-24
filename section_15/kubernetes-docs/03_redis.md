# `03_redis.yml` - Redis cache

This file has two objects in it, separated by `---`: a **Deployment** (runs Redis) and a
**Service** (gives it a stable address other pods can reach).

## What this is for

Redis is an in-memory data store. In this app, the gateway (`13_gateway.yml`) uses it for
rate limiting (tracking how many requests a client has made recently) and reports on its
connection to Redis as part of its own health check.

## The Deployment

```yaml
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7.4-alpine
          ports:
            - containerPort: 6379
```
- `replicas: 1` - run exactly one copy. Redis here has no persistence configured (no
  volume), so if this pod restarts, whatever was cached is simply gone and rebuilt over
  time - that's fine for a rate-limiter cache, would not be fine for data you need to keep.
- `selector.matchLabels` / `template.metadata.labels` - these have to match each other. This
  is how the Deployment knows which pods it "owns": it manages any pod carrying the label
  `app: redis`.
- `image: redis:7.4-alpine` - the official Redis image, pinned to version 7.4 on the small
  `alpine` base (smaller download, smaller attack surface than the default image).
- `containerPort: 6379` - Redis's default port, just documents which port the container
  listens on (doesn't by itself open anything to the network - that's the Service's job).

**Probes**: `readinessProbe`/`livenessProbe` both use `tcpSocket: port: 6379` - "can I open a
TCP connection to this port?" That's a lightweight way to health-check something like Redis
that doesn't have a dedicated HTTP health endpoint.

**Resources**: `requests: cpu: 100m, memory: 64Mi` / `limits: cpu: 250m, memory: 256Mi` -
Redis is lightweight, so it gets a small guaranteed slice of CPU/memory (`requests`) and a
low ceiling (`limits`) before it'd be throttled (CPU) or killed (memory).

## The Service

```yaml
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  type: ClusterIP
  ports:
    - port: 6379
      targetPort: 6379
```
- `selector: app: redis` - routes traffic to any pod labeled `app: redis` (i.e., the pods
  created by the Deployment above).
- `type: ClusterIP` - only reachable from inside the cluster. Nothing outside the cluster
  needs to talk to Redis directly, so it doesn't get a `LoadBalancer`.
- `port: 6379` / `targetPort: 6379` - "requests to `redis:6379` get forwarded to port `6379`
  on the matching pod." They happen to be the same number here, but they don't have to be.

Other services reach this over the network at the hostname `redis`, e.g. the gateway's
`SPRING_DATA_REDIS_HOST` environment variable is set to `redis` (from the ConfigMap).
