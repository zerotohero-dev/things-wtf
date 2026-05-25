# 05 · The Reconcile Loop — The Core Algorithm

Everything in operator development flows from one function signature:

```go
func (r *MyReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // req.NamespacedName = "namespace/name" of the object to reconcile.
    // NOT a delta. NOT an event. Just: "go look at this object."
}
```

The request carries *only* the identity of the object (namespace + name). It does
not tell you what changed or why. This is intentional.

---

## The six steps of every reconciler

**1. Fetch the current object from the cache**

Read the full current spec and status. If the object is gone (deleted and not found),
handle that case cleanly.

**2. Read the actual world state**

Check what resources actually exist: is the Secret present? Is the external service
registered? What's the current SVID expiry?

**3. Compute the gap between desired and actual**

Compare spec (what you want) against what you observed.

**4. Take actions to close the gap**

Create, update, or delete resources. Call external APIs. Only touch what needs to
change.

**5. Update status to reflect what you observed**

Set conditions, phase, `observedGeneration`. Patch status via the status subresource.

**6. Return the appropriate Result**

Tell the runtime when (or whether) to run again.

---

## Idempotency — the non-negotiable property

Your reconciler *will* be called multiple times for the same object state. Network
blips, leader elections, and periodic re-syncs all cause re-reconciliation. Your
code must be **idempotent**: running it N times must have the same effect as
running it once.

The pattern is always *ensure*, not *create*:

```go
// BAD — not idempotent. Second call fails with "already exists".
func (r *R) createSecret(ctx context.Context, sc *v1alpha1.SpikeConfig) error {
    secret := buildSecret(sc)
    return r.Create(ctx, secret)  // ← panics on second call
}

// GOOD — idempotent. Creates if absent, updates if present and stale.
func (r *R) ensureSecret(ctx context.Context, sc *v1alpha1.SpikeConfig) error {
    desired := buildSecret(sc)
    existing := &corev1.Secret{}

    err := r.Get(ctx, client.ObjectKeyFromObject(desired), existing)
    if apierrors.IsNotFound(err) {
        return r.Create(ctx, desired)
    }
    if err != nil {
        return err
    }

    // Only patch if content actually differs
    if !secretNeedsUpdate(existing, desired) {
        return nil
    }

    patch := client.MergeFrom(existing.DeepCopy())
    existing.Data = desired.Data
    return r.Patch(ctx, existing, patch)
}
```

---

## Result return values

```go
// Done. Don't requeue unless a watch event fires.
return ctrl.Result{}, nil

// Done, but requeue after a delay.
// Use this when polling external state (cert expiry, external service health).
return ctrl.Result{RequeueAfter: 30 * time.Second}, nil

// Done, requeue immediately.
// Use sparingly — usually means you did partial work and need another pass.
return ctrl.Result{Requeue: true}, nil

// Error — controller-runtime requeues with exponential backoff.
// Rate: 5ms → 10ms → 20ms → ... up to 1000s (configurable).
return ctrl.Result{}, fmt.Errorf("failed to provision SVID: %w", err)
```

!!! danger "Don't swallow errors"

    Returning `ctrl.Result{}, nil` when something failed means the controller will
    **never retry** unless a new watch event arrives. Always return the error so the
    runtime retries with backoff. If you handle an error by logging it and returning
    `nil`, you have created a silent failure mode.

---

## What triggers a reconcile

Your reconciler is called when any of these happen:

- A watched object is **created, modified, or deleted** (via the informer watch stream)
- A **requeue** fires (from `RequeueAfter` or `Requeue: true` in the previous result)
- An **error** from the previous reconcile triggers the backoff retry
- A **periodic resync** fires (configurable; off by default in controller-runtime)
- The **controller restarts** — it re-lists all objects and queues them all

The last point is worth emphasizing: **every restart queues every object**. Your
reconciler must handle "nothing changed, everything is fine" quickly and cheaply,
because it runs at restart for every object you manage.

??? example "Deep dive: the thundering herd problem on restart"

    When a controller starts or restarts, the informer cache performs a **full
    List** of every object of every watched type. For a cluster with 10,000
    `SpikeConfig` objects, this triggers 10,000 reconcile requests simultaneously.
    This is the **thundering herd**.

    Mitigations:

    - `MaxConcurrentReconciles` in `WithOptions` — limits concurrent workers
    - `RateLimiter` in `WithOptions` — token bucket or item exponential backoff
    - Idempotent reconcilers that detect "nothing to do" early and return quickly
      without hitting external systems
    - Caching external client responses (SPIRE gRPC calls, Vault reads) with short TTLs

    For operators managing external systems like SPIRE or Vault, a thundering herd
    on restart can saturate your identity plane. Design for this explicitly.
