# Mental Model

Kubernetes is a **declarative reconciliation engine**. You write desired state into etcd via the API server; controllers watch that state, compare it to observed reality, and issue imperative calls to converge. You never say "create this pod" — you say "the desired number of replicas is 3" and trust the controller loop.

## Three axioms

### Level-triggered

Controllers respond to *current state*, not event streams. A controller that misses an event will still converge on the next reconcile cycle — idempotent by design.

Compare to edge-triggered systems (like traditional message queues): if a message is missed, the action is lost. In Kubernetes, the controller re-observes reality on every cycle — a missed watch event is harmless.

### Optimistic concurrency

Every object has a `resourceVersion` (an etcd revision). Writes must include it; stale writes return `409 Conflict`. No distributed locks.

```
# The write path:
GET object → modify in memory → PUT/PATCH with resourceVersion
                                      ↓
                           API server checks: does RV match etcd?
                           No  → 409 Conflict, retry
                           Yes → write accepted, new RV assigned
```

### Edge-case safety

Controllers use work queues with rate limiting + exponential backoff. Objects are re-enqueued on error; transient failures self-heal. The queue is also deduplicating — if an object is enqueued multiple times before processing, it's processed once.

## The reconcile loop

The canonical pattern every controller follows:

```
1. GET current object from local cache
2. Compare .spec (desired) with .status (observed)
3. Issue imperative calls to close the gap (create/update/delete child resources)
4. Update .status to reflect current reality
5. On any error → requeue with exponential backoff
```

In Go with controller-runtime:

```go
func (r *MyReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    obj := &myv1.MyResource{}
    if err := r.Get(ctx, req.NamespacedName, obj); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err) // deleted — done
    }

    // Compute desired state, apply delta
    if err := r.ensureChildResources(ctx, obj); err != nil {
        return ctrl.Result{}, err // requeue with backoff
    }

    // Report observed state
    obj.Status.Phase = "Running"
    if err := r.Status().Update(ctx, obj); err != nil {
        return ctrl.Result{}, err
    }

    return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
}
```

!!! note
    Always use `client.IgnoreNotFound` on the initial GET. The object may have been deleted between the time it was enqueued and the time the reconciler runs — that's normal, not an error.

## Desired state vs observed state

Every Kubernetes object has two logical sections:

| Field | Meaning | Written by |
|---|---|---|
| `.spec` | Desired state | The user / operator |
| `.status` | Observed state | The controller |

The `.status` subresource is separate from `.spec` intentionally — it requires separate RBAC (`update` on `foos/status`), and writes to status don't bump `.metadata.generation` (which only increments on spec changes). Controllers use `generation` vs `observedGeneration` to detect whether they've caught up to the latest spec.

## Why declarative?

The alternative — imperative orchestration ("run these steps in order") — breaks under partial failure. If step 3 of 5 fails and you retry, you need to know whether steps 1 and 2 are still valid. Declarative reconciliation sidesteps this: the reconciler always starts from current reality, compares to desired state, and applies only the delta. Re-running it is always safe.

This is why Kubernetes controllers are said to be **idempotent**: running the reconcile loop N times on an already-converged system produces the same result as running it once.
