# Leader Election

In production, you run multiple replicas of your operator for availability. But only one should be reconciling at a time — otherwise you get split-brain with conflicting updates. Leader election solves this via a Kubernetes `Lease` object.

---

## How It Works

```text
Operator Pod A ──┐
                 ├──▶ Compete for Lease "webapp-operator.example.com"
Operator Pod B ──┘    in namespace "webapp-operator-system"
                             │
                    ┌────────▼────────┐
                    │  Pod A wins     │
                    │  (acquires Lease)│
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
         Pod A runs      Pod B watches  Pod C watches
         reconcile       Lease, ready   Lease, ready
         loop            to take over   to take over
                         if A fails     if A fails
```

Pod A renews the Lease periodically. If it fails to renew (crash, network partition), the Lease expires. Pods B and C will race to acquire it. The winner begins reconciling.

---

## Configuration

```go title="cmd/main.go"
mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
    // Enable leader election
    LeaderElection: true,

    // Unique ID per operator — avoids conflicts between different operators
    // in the same namespace. Use a fully-qualified name.
    LeaderElectionID: "webapp-operator.example.com",

    // Namespace for the Lease object
    LeaderElectionNamespace: "webapp-operator-system",

    // LeaseDuration: validity period of the lease.
    // If leader dies, others wait at most this long before taking over.
    LeaseDuration: ptr(15 * time.Second),

    // RenewDeadline: leader must renew the lease within this window or lose it.
    // Must be < LeaseDuration.
    RenewDeadline: ptr(10 * time.Second),

    // RetryPeriod: how often non-leaders attempt to acquire the lease.
    RetryPeriod: ptr(2 * time.Second),

    // Release lease on graceful shutdown (SIGTERM).
    // Enables immediate failover during rolling updates — new pod acquires
    // lease immediately rather than waiting for LeaseDuration to expire.
    LeaderElectionReleaseOnCancel: true,
})
```

---

## Tuning the Lease Timings

| Parameter | Too low | Too high | Recommended |
|-----------|---------|---------|-------------|
| `LeaseDuration` | Frequent false leader loss under API server pressure | Slow failover on crash | 15–30s |
| `RenewDeadline` | Leader loses lease unnecessarily | N/A | ~2/3 of LeaseDuration |
| `RetryPeriod` | High Lease churn, many writes | Slow leader election | 2–5s |

!!! warning "Don't go below 10s/7s/2s in production"
    Very short lease durations + any API server latency = leader constantly losing and reacquiring the lease → reconcile gaps and log noise. The defaults are conservative on purpose.

---

## LeaderElectionReleaseOnCancel — Essential for Rolling Updates

Without `LeaderElectionReleaseOnCancel: true`:

1. Old pod receives SIGTERM, shuts down
2. Lease still valid for up to `LeaseDuration` (15s)
3. New pod must wait up to 15s before acquiring lease
4. 15-second reconcile gap during every deployment

With `LeaderElectionReleaseOnCancel: true`:

1. Old pod receives SIGTERM, releases lease immediately
2. New pod acquires lease within `RetryPeriod` (2s)
3. ~2-second gap during deployment

Always set this to `true` for production operators.

---

## RBAC for Leader Election

The leader election Lease requires these permissions — controller-gen generates them if you add the marker:

```go
// +kubebuilder:rbac:groups=coordination.k8s.io,resources=leases,verbs=get;list;watch;create;update;patch;delete
```

---

## Verifying Leader Election

```bash
# See which pod holds the lease
kubectl get lease webapp-operator.example.com \
  -n webapp-operator-system \
  -o jsonpath='{.spec.holderIdentity}'

# Watch lease transitions
kubectl get lease webapp-operator.example.com \
  -n webapp-operator-system -w

# Full lease details
kubectl describe lease webapp-operator.example.com \
  -n webapp-operator-system
```
