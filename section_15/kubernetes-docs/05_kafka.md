# `05_kafka.yml` - the Kafka broker

Two objects: a **Deployment** (runs Kafka) and a **Service** (gives it a stable address).

## What this is for

Kafka is a message broker: services publish "events" to it, and other services subscribe
to receive them, without the publisher and subscriber having to talk to each other directly.
In this app, `accounts` publishes an event when a new account is opened, and `message`
consumes it to (pretend to) send a welcome email/SMS - see [09_accounts.md](09_accounts.md)
and [12_message.md](12_message.md).

## Why a Deployment, and no persistent storage?

This setup is meant for local testing and demos, so Kafka's data is **not** persisted.
Topics and messages live on the container's own filesystem and are lost whenever the pod
restarts or is recreated. For a demo that's fine - topics are simply created again the
next time `accounts`/`message` use them.

In production you'd normally run Kafka as a **StatefulSet** with `volumeClaimTemplates`,
so each broker gets a stable name (`kafka-0`, `kafka-1`, ...) and its own disk that
survives restarts. With one broker and no storage, neither of those matters here, so a
plain Deployment is enough.

```yaml
spec:
  replicas: 1
  strategy:
    type: Recreate
```
- `strategy: Recreate` - by default a Deployment does a *rolling* update: it starts the new
  pod before stopping the old one. For Kafka that would briefly give you two separate
  single-broker "clusters" behind the same `kafka` Service, with messages split between
  them. `Recreate` stops the old pod first, then starts the new one.

## The Kafka configuration (KRaft mode)

This app doesn't run a separate Zookeeper - Kafka manages its own metadata internally
("KRaft mode"), which is the modern, simpler way to run it. The env vars configure that:

- `KAFKA_PROCESS_ROLES: "broker,controller"` - this one Kafka pod plays both roles (handling
  data *and* managing cluster metadata) since we only have one broker.
- `KAFKA_NODE_ID: "1"` - this node's unique ID in the cluster.
- `KAFKA_LISTENERS` - the two network ports Kafka listens on:
  - `PLAINTEXT` on `9092` - used by application clients (`accounts`/`message`).
  - `CONTROLLER` on `9093` - used internally for metadata (controller) traffic.
- `KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092"` - the address Kafka *tells clients*
  to use when they connect. It must match the `kafka` Service name and port, which is also
  what the ConfigMap's `KAFKA_BROKER` points at.
- `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` / `KAFKA_CONTROLLER_LISTENER_NAMES` - map each
  listener name to a security protocol (`PLAINTEXT` here - no TLS/auth, fine for learning,
  not for production) and say which listener carries controller traffic.
- `KAFKA_CONTROLLER_QUORUM_VOTERS: "1@localhost:9093"` - "the controller quorum consists of
  node 1, reachable at `localhost:9093`." Since the broker and controller run in the same
  container, `localhost` is enough, and the controller port never needs to be exposed on the
  Service. With more brokers, you'd list all of them here.
- `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR`, `KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR`,
  `KAFKA_TRANSACTION_STATE_LOG_MIN_ISR`: all `"1"` - Kafka's internal topics (that track
  consumer progress and transactions) would normally be replicated across multiple brokers
  for safety; with only one broker, a replication factor above 1 is impossible, so these are
  all set to 1.
- `KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: "0"` - lets consumers start receiving messages
  immediately instead of waiting the default 3 seconds for other group members to join.
- `CLUSTER_ID` - the ID Kafka uses to format its storage when it starts up.

**Probes**: all three (`startupProbe`/`readinessProbe`/`livenessProbe`) use `tcpSocket: port:
9092` - same idea as Redis's probe, just "can a connection be opened on Kafka's client
port?"

## The Service

```yaml
type: ClusterIP
ports:
  - name: broker
    port: 9092
```
`ClusterIP` because nothing outside the cluster needs to publish/consume Kafka events
directly - only other pods in this app do (`accounts`, `message`). Only the client port
(`9092`) is exposed; the controller port stays internal to the container.
