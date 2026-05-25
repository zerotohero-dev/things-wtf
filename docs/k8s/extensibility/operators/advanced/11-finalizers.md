# 11 · Finalizers

Finalizers are strings in `metadata.finalizers` that block object deletion. When
you run `kubectl delete spikeconfig my-config`, the API server sets
`DeletionTimestamp` but does **not** delete the object. It stays in "Terminating"
state until all finalizers are removed. Your controller must remove its finalizer
after completing cleanup.

---

## Lifecycle

```
Object created          Reconciler runs         kubectl delete
     │                       │                       │
     │                 Adds finalizer          Sets DeletionTimestamp
     │                 Does real work               │
     │                       │                       │
     └───────────────────────────────────────────────┘
                                       │
                              Reconciler sees
                              DeletionTimestamp != 0
                                       │
                              External cleanup
                              (SPIFFE entry, etc.)
                                       │
                              Remove finalizer
                              r.Update(ctx, sc)
                                       │
                              API server GC
                              deletes object
```

!!! warning "If cleanup fails, the object is stuck"

    If your operator is down or the cleanup function errors, the object stays in
    Terminating forever. The only recourse is manual intervention — see
    [the 2am playbook](../production/21-2am-playbook.md).

---

## Implementation pattern

```go
const FinalizerName = "spike.io/finalizer"

func (r *R) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var sc spikev1alpha1.SpikeConfig
    if err := r.Get(ctx, req.NamespacedName, &sc); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    if !sc.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, &sc)
    }

    if !controllerutil.ContainsFinalizer(&sc, FinalizerName) {
        controllerutil.AddFinalizer(&sc, FinalizerName)
        return ctrl.Result{}, r.Update(ctx, &sc)
    }

    return r.reconcileNormal(ctx, &sc)
}

func (r *R) handleDeletion(ctx context.Context, sc *v1alpha1.SpikeConfig) (ctrl.Result, error) {
    if !controllerutil.ContainsFinalizer(sc, FinalizerName) {
        return ctrl.Result{}, nil
    }

    // This must be idempotent — may run multiple times on failure.
    if err := r.cleanupSPIFFEEntry(ctx, sc); err != nil {
        return ctrl.Result{}, err
    }

    controllerutil.RemoveFinalizer(sc, FinalizerName)
    return ctrl.Result{}, r.Update(ctx, sc)
}
```

---

## Force-removing a stuck finalizer

```bash
# Only do this after manually verifying external cleanup, or accepting the leak.
kubectl patch spikeconfig my-config \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge
```

!!! tip "Design for operator downtime"

    If someone deletes a resource while your operator is down for maintenance,
    they'll be blocked. Consider making cleanup async: record the intent to delete
    externally, remove the finalizer immediately, let a background job finish
    the actual cleanup. This decouples operator availability from deletion latency.
