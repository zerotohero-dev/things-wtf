# Finalizers & Deletion Lifecycle

Finalizers are strings in `metadata.finalizers`. When present, Kubernetes sets `metadata.deletionTimestamp` on delete but does **not** remove the object until all finalizers are gone. This gives your controller a window to do cleanup.

---

## When to Use Finalizers

Use finalizers when you manage resources that Kubernetes GC **cannot** clean up automatically:

- External DNS records
- Cloud load balancers or security groups
- Database entries or users
- Certificates in external PKI
- Entries in external registries or inventories

For resources you create in Kubernetes with owner references, you **don't need finalizers** — GC handles those automatically. See [§07 Ownership & GC](./07-ownership-gc.md).

---

## The Deletion State Machine

```text
kubectl delete webapp my-app
        │
        ▼
API Server sets DeletionTimestamp (object NOT deleted yet)
Object is updated → watch event fires → Reconcile is called
        │
        ▼
Controller sees DeletionTimestamp.IsZero() == false
Runs cleanup logic:
  - Deregister from external DNS
  - Delete cloud load balancer
  - Revoke external certificates
        │
        │ cleanup done
        ▼
Remove finalizer string from metadata.finalizers
Call r.Update(ctx, webapp)
        │
        ▼
API server sees empty finalizers
→ Object is ACTUALLY deleted from etcd
→ GC cascades to owned resources
```

---

## Full Finalizer Implementation

```go title="internal/controller/webapp_controller.go"
const finalizerName = "apps.example.com/webapp-finalizer"

func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    webapp := &appsv1alpha1.WebApp{}
    if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // ── Register finalizer on first reconcile ────────────────────────────
    // Only add if the object is NOT being deleted (DeletionTimestamp is zero)
    if !controllerutil.ContainsFinalizer(webapp, finalizerName) && webapp.DeletionTimestamp.IsZero() {
        controllerutil.AddFinalizer(webapp, finalizerName)
        if err := r.Update(ctx, webapp); err != nil {
            return ctrl.Result{}, fmt.Errorf("adding finalizer: %w", err)
        }
        // Return here — the Update triggers a new reconcile with the finalizer set.
        // We'll continue normal reconcile logic on the next call.
        return ctrl.Result{}, nil
    }

    // ── Handle deletion ──────────────────────────────────────────────────
    if !webapp.DeletionTimestamp.IsZero() {
        if controllerutil.ContainsFinalizer(webapp, finalizerName) {
            // Do your cleanup here.
            // If cleanup fails, the object stays in Terminating state.
            if err := r.cleanupExternalResources(ctx, webapp); err != nil {
                return ctrl.Result{}, fmt.Errorf("cleanup: %w", err)
            }

            // Cleanup done — remove the finalizer to unblock deletion.
            controllerutil.RemoveFinalizer(webapp, finalizerName)
            if err := r.Update(ctx, webapp); err != nil {
                return ctrl.Result{}, fmt.Errorf("removing finalizer: %w", err)
            }
        }
        // Object is being deleted — stop reconciling normal state.
        return ctrl.Result{}, nil
    }

    // ── Normal reconcile logic ───────────────────────────────────────────
    return r.reconcileNormal(ctx, webapp)
}

func (r *WebAppReconciler) cleanupExternalResources(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    log := log.FromContext(ctx)

    // Use a timeout so cleanup can't block indefinitely
    cleanupCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    if err := r.dnsClient.DeleteRecord(cleanupCtx, webapp.Spec.Ingress.Host); err != nil {
        // If the record doesn't exist, that's fine — idempotent cleanup
        if !isDNSNotFound(err) {
            return fmt.Errorf("deleting DNS record: %w", err)
        }
        log.Info("DNS record already removed", "host", webapp.Spec.Ingress.Host)
    }

    return nil
}
```

---

## The Gotchas

!!! danger "Cannot add a finalizer after DeletionTimestamp is set"
    If the object already has a `DeletionTimestamp` (it's being deleted), the API server will **reject** any attempt to add a new finalizer. Always check `webapp.DeletionTimestamp.IsZero()` before adding:

    ```go
    // WRONG — will be rejected by API server if deletion is in progress
    controllerutil.AddFinalizer(webapp, finalizerName)
    r.Update(ctx, webapp)

    // CORRECT
    if webapp.DeletionTimestamp.IsZero() {
        controllerutil.AddFinalizer(webapp, finalizerName)
        r.Update(ctx, webapp)
    }
    ```

!!! warning "Finalizer deadlocks are real"
    If your cleanup logic calls an external service that is down, the object will be stuck in `Terminating` forever — until you either fix the service or manually remove the finalizer:

    ```bash
    kubectl patch webapp my-app \
      -p '{"metadata":{"finalizers":[]}}' \
      --type=merge
    ```

    Design cleanup to be resilient:
    - Use timeouts on external calls
    - Handle "already deleted" as success (idempotent)
    - Consider whether cleanup is truly required vs. "best effort with a warning"

!!! warning "Multiple finalizers — order matters for some use cases"
    If you have multiple finalizers, they're removed one at a time. Each removal triggers a reconcile. If finalizer A's cleanup depends on resources cleaned up by finalizer B, you need to manage the order explicitly, not rely on the slice order in `metadata.finalizers`.

---

## Checking Deletion State in Sub-Functions

When you factor out sub-reconcile functions, they may need to know if the object is being deleted:

```go
func (r *WebAppReconciler) reconcileIngress(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    // If we're being deleted, don't create new resources
    if !webapp.DeletionTimestamp.IsZero() {
        return nil
    }

    // ... normal ingress reconciliation ...
}
```

---

## Observing Finalizers in the Wild

```bash
# See finalizers on an object
kubectl get webapp my-app -o jsonpath='{.metadata.finalizers}'

# Watch deletion progress
kubectl get webapp my-app -w

# Force-remove a stuck finalizer (emergency only)
kubectl patch webapp my-app \
  --type=json \
  -p='[{"op":"remove","path":"/metadata/finalizers/0"}]'
```
