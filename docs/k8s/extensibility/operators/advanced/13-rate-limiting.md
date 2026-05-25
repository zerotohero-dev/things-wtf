# Rate Limiting & Work Queues

The work queue uses a rate limiter to prevent runaway retry loops. When `Reconcile` returns an error, the item is re-queued with exponential backoff. Understanding and tuning this prevents both thundering herds and sluggish recovery.

---

## How the Default Rate Limiter Works

controller-runtime uses `workqueue.DefaultControllerRateLimiter()` by default, which is a `MaxOfRateLimiter` combining:

1. **`ItemExponentialFailureRateLimiter`**: Per-item exponential backoff
   - First failure: 5ms delay
   - Each subsequent failure: 2× the previous (5ms → 10ms → 20ms → ... → 1000s)
   - Resets when the item succeeds

2. **`BucketRateLimiter`**: Overall token bucket
   - 10 items/second with burst of 100

This means a single misbehaving object (returning errors on every reconcile) will eventually back off to 1000 seconds between retries — it won't spin the CPU.

---

## Custom Rate Limiters

```go title="internal/controller/webapp_controller.go — SetupWithManager"
import (
    "sigs.k8s.io/controller-runtime/pkg/controller"
    "k8s.io/client-go/util/workqueue"
    "golang.org/x/time/rate"
)

func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    rateLimiter := workqueue.NewMaxOfRateLimiter(
        workqueue.NewItemExponentialFailureRateLimiter(
            500*time.Millisecond, // base delay on first failure
            30*time.Second,       // max delay cap
        ),
        &workqueue.BucketRateLimiter{
            Limiter: rate.NewLimiter(
                rate.Limit(10), // 10 reconciles/sec overall
                100,            // burst of 100
            ),
        },
    )

    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.WebApp{}).
        WithOptions(controller.Options{
            RateLimiter:             rateLimiter,
            MaxConcurrentReconciles: 5,
        }).
        Complete(r)
}
```

### Tuning Guidelines

| Scenario | Recommendation |
|----------|---------------|
| Operator with external API calls (slow, high latency) | Reduce base delay to 200ms, increase `MaxConcurrentReconciles` |
| Operator managing many small objects | Increase bucket rate to 50/s with burst 200 |
| Operator where errors are rare but should recover fast | Keep base delay at 100ms, reduce max to 10s |
| Conservative/production operator | Defaults are reasonable; tune max delay to 60s |

---

## MaxConcurrentReconciles

By default, a controller has 1 worker (serial). Increase this for parallelism:

```go
controller.Options{
    MaxConcurrentReconciles: 5,
}
```

**When to increase:**

- Your reconcile makes **external calls** with high latency (DNS, cert-manager, cloud APIs)
- You have many **independent CRs** (different WebApps don't share state)
- You observe a **large queue depth** (many items waiting while workers are idle)

**When NOT to increase:**

- Your reconcile reads then writes the same object with race-prone logic
- You're using a shared external resource with strict rate limits

!!! info "Concurrent reconciles for different objects are safe"
    The work queue deduplicates **per namespace/name key**. Two reconciles for the same WebApp will never run concurrently. Two reconciles for different WebApps can run concurrently — this is safe because they operate on independent objects.

---

## The Work Queue Is Deduplicating

!!! tip "Burst events don't cause burst reconciles"
    If 100 events arrive for the same WebApp before a reconcile worker picks it up, the queue contains **one entry** for that WebApp. Your reconciler runs once and fetches current state. This is a major benefit of the level-triggered model.

    Compare with edge-triggered: 100 events → 100 reconcile calls, each potentially doing redundant work.

---

## Observing Queue Behavior via Metrics

controller-runtime exposes Prometheus metrics for the work queue:

```bash
kubectl port-forward -n webapp-operator-system svc/webapp-operator-metrics 8080

# Queue depth — items waiting to be processed
curl -s http://localhost:8080/metrics | grep 'workqueue_depth'

# How long items wait in queue before being processed
curl -s http://localhost:8080/metrics | grep 'workqueue_queue_duration_seconds'

# Reconcile duration
curl -s http://localhost:8080/metrics | grep 'controller_runtime_reconcile_time_seconds'

# Reconcile errors
curl -s http://localhost:8080/metrics | grep 'controller_runtime_reconcile_errors_total'
```

A healthy operator should show:
- `workqueue_depth` near 0 most of the time
- `controller_runtime_reconcile_errors_total` low and not continuously climbing
- `workqueue_queue_duration_seconds` under 1 second for the p99
