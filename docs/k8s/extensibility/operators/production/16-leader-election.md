# 16 · Leader Election & High Availability

Most operator patterns involve shared state (the Kubernetes API) and external state
(Vault, SPIRE, databases). Running multiple operator replicas that all reconcile
the same object concurrently would cause conflicts. **Leader election** ensures only
one replica is active at a time, with others standing by.

---

## How it works

Leader election state is stored in a `coordination.k8s.io/v1/Lease` object. The
active leader continuously renews this lease. If the leader fails to renew within
`LeaseDuration`, a standby replica acquires it and becomes the new leader.

```
Replica A (leader)   Replica B (standby)   Replica C (standby)
      │                     │                      │
  reconciling           watching lease         watching lease
      │                     │                      │
  renews lease              │                      │
      │                     │                      │
   (crashes)                │                      │
      ✗                     │                      │
                    waits LeaseDuration             │
                            │                      │
                       acquires lease               │
                            │                      │
                        reconciling             watching lease
```

---

## Configuration

```go
leaseDuration := 15 * time.Second  // how long before a dead leader is replaced
renewDeadline  := 10 * time.Second  // leader must renew within this or yield
retryPeriod    :=  2 * time.Second  // how often standbys poll the lease

mgr, err := ctrl.NewManager(cfg, ctrl.Options{
    LeaderElection:          true,
    LeaderElectionID:        "spike-operator-leader",  // must be unique per operator
    LeaderElectionNamespace: "spike-system",
    LeaseDuration:           &leaseDuration,
    RenewDeadline:           &renewDeadline,
    RetryPeriod:             &retryPeriod,
})
```

!!! warning "LeaderElectionID must be unique per operator"

    If two different operators share the same `LeaderElectionID`, their leader
    election will interfere — one operator can steal the lease from another.
    Use a name that includes your operator's full name, e.g.
    `spike-operator.spike.io`.

---

## Inspecting the lease

```bash
kubectl -n spike-system get lease spike-operator-leader -o yaml
# spec.holderIdentity: spike-operator-7d8f6-xyz   ← current leader pod
# spec.acquireTime:    "2026-04-01T00:00:00Z"
# spec.renewTime:      "2026-04-03T12:34:56Z"     ← if stale, leader is dead
# spec.leaseDurationSeconds: 15
```

If `renewTime` is more than `leaseDuration` seconds in the past, the leader is
dead and the lease has not been claimed — nothing is reconciling.

---

## The gap during leader transition

!!! warning "Reconciliation stops during leader transition"

    When a leader dies, there is a window of up to `LeaseDuration` where **no
    reconciliation runs**. For operators managing time-sensitive resources (SVID
    rotation, certificate renewal), this gap matters.

    Design for it:

    - Set `RequeueAfter` intervals shorter than your minimum resource TTL
    - For a 24h SVID TTL, a 15-second gap is irrelevant
    - For a 1h SVID TTL, rotate at 50m (10-minute buffer), so missing one cycle
      still leaves 50 minutes before expiry
    - For a 5-minute TTL, leader election with a 15-second gap is a real problem —
      consider shorter lease durations or a different architecture

---

## Multiple replicas are still useful

Even though only one replica reconciles, running 2–3 replicas is valuable:

- Leader transition is fast (seconds, not minutes)
- The webhook server runs on **all** replicas — webhooks benefit from HA even
  though the controller itself is single-active
- A second replica provides immediate failover with no manual intervention

```yaml
# config/manager/manager.yaml
spec:
  replicas: 2
  # Pod anti-affinity keeps replicas on different nodes
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: spike-operator
            topologyKey: kubernetes.io/hostname
```
