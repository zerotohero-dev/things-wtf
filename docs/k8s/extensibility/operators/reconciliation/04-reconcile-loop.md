# The Reconcile Loop — Deep Dive

The reconcile function's signature is fixed:

```go
func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error)
```

`req` contains only the **namespace/name** key of the object that triggered reconciliation. You don't know *why* it was called. Don't assume.

---

## Idempotency Contracts

Your reconcile function must be **safe to call multiple times with the same input**. The controller-runtime will call it repeatedly:

- On operator startup (re-sync of all watched objects)
- After errors (backoff retry)
- On any watch event from owned resources
- On any spec or status change to the CR
- Periodically if you use `RequeueAfter`

If running the same reconcile twice puts the world in a bad state, you have a bug.

---

## The Standard Reconcile Structure

```go title="internal/controller/webapp_controller.go"
func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // ── Step 1: Fetch the resource from cache ────────────────────────────
    // Always fetch first. The object may have been deleted between the event
    // being enqueued and us processing it.
    webapp := &appsv1alpha1.WebApp{}
    if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
        if apierrors.IsNotFound(err) {
            // Object was deleted before we got to process it. Nothing to do —
            // Kubernetes GC will clean up owned resources via owner references.
            log.Info("WebApp not found, likely deleted")
            return ctrl.Result{}, nil
        }
        // Any other error is transient — requeue with backoff.
        return ctrl.Result{}, fmt.Errorf("fetching WebApp: %w", err)
    }

    // ── Step 2: Handle deletion via finalizer ────────────────────────────
    // See §06 for full finalizer pattern.
    if !webapp.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, webapp)
    }

    // ── Step 3: Reconcile owned resources ────────────────────────────────
    // Use a multi-error approach so we attempt ALL sub-reconciliations even
    // if one fails. Partial progress is better than none.
    var errs []error

    if err := r.reconcileDeployment(ctx, webapp); err != nil {
        errs = append(errs, fmt.Errorf("deployment: %w", err))
    }
    if err := r.reconcileService(ctx, webapp); err != nil {
        errs = append(errs, fmt.Errorf("service: %w", err))
    }
    if webapp.Spec.Ingress != nil {
        if err := r.reconcileIngress(ctx, webapp); err != nil {
            errs = append(errs, fmt.Errorf("ingress: %w", err))
        }
    }

    // ── Step 4: Update status ─────────────────────────────────────────────
    // Always update status, even on partial failure — report what we know.
    if statusErr := r.updateStatus(ctx, webapp); statusErr != nil {
        errs = append(errs, fmt.Errorf("status update: %w", statusErr))
    }

    return ctrl.Result{}, errors.Join(errs...)
}
```

---

## Requeue Strategies

The return value from `Reconcile` controls what the work queue does next. Getting this wrong causes either thundering-herd problems or objects that never get re-examined.

| Return value | Behavior | When to use |
|-------------|----------|-------------|
| `Result{}, nil` | Success — no requeue unless a watch event fires | Everything converged, no polling needed |
| `Result{}, err` | Requeue with **exponential backoff** (base 5ms → max 1000s) | Transient errors (API server unavailable, etc.) |
| `Result{Requeue: true}, nil` | Requeue immediately after current queue drains | Rarely correct — see warning below |
| `Result{RequeueAfter: d}, nil` | Requeue after fixed duration, **no backoff** | Polling external state (cert expiry, quota, DNS) |

!!! warning "Requeue: true almost always wrong"
    `Result{Requeue: true}` does NOT apply rate limiting or backoff. If your reconcile function keeps returning it — say, waiting for a pod to become ready — you create a **busy-loop** that hammers the API server.

    Use `RequeueAfter` with a sensible duration instead, and let watch events drive you when the awaited state change actually happens.

    ```go
    // WRONG — spin loop waiting for deployment to be ready
    if dep.Status.ReadyReplicas < *dep.Spec.Replicas {
        return ctrl.Result{Requeue: true}, nil
    }

    // CORRECT — let the Deployment watch event wake us up,
    // with a fallback poll in case we miss an event
    if dep.Status.ReadyReplicas < *dep.Spec.Replicas {
        return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
    }
    ```

---

## Error Handling Patterns

```go title="internal/controller — error patterns"
// ── Pattern 1: Wrap errors with context ─────────────────────────────────
// Use %w so errors.Is/As chains work upstream
if err := r.Client.Create(ctx, deployment); err != nil {
    return ctrl.Result{}, fmt.Errorf("creating Deployment %s/%s: %w", ns, name, err)
}

// ── Pattern 2: AlreadyExists is not an error on Create ──────────────────
// Another concurrent reconcile may have created it already — that's fine.
if err := r.Client.Create(ctx, desired); err != nil {
    if !apierrors.IsAlreadyExists(err) {
        return ctrl.Result{}, fmt.Errorf("creating resource: %w", err)
    }
    // Race condition: another reconcile created it first. Continue normally.
}

// ── Pattern 3: Conflict on Update requires re-fetch ─────────────────────
// Do NOT retry the same update — re-fetch, re-compute, re-apply.
// Returning an error causes the queue to requeue with backoff, which will
// re-fetch fresh state from the cache on the next call.
if apierrors.IsConflict(err) {
    return ctrl.Result{}, fmt.Errorf("conflict, will requeue: %w", err)
}

// ── Pattern 4: Terminal errors — stop retrying ──────────────────────────
// Use reconcile.TerminalError for bugs that won't be fixed by retrying.
// The object will only be reconciled again on the next watch event (spec change).
import "sigs.k8s.io/controller-runtime/pkg/reconcile"

if invalidConfig {
    return ctrl.Result{}, reconcile.TerminalError(
        fmt.Errorf("invalid config: image name cannot contain spaces"),
    )
}
```

---

## Server-Side Apply for Create-or-Update

For create-or-update patterns, prefer **Server-Side Apply (SSA)** over the classic Get→Create/Update pattern. SSA is declarative, handles conflicts via field ownership, and eliminates entire classes of race conditions.

```go title="internal/controller — SSA pattern"
func (r *WebAppReconciler) applyDeployment(ctx context.Context, desired *appsv1.Deployment) error {
    // Apply with force=true and a unique fieldManager.
    // The API server tracks which fields this manager "owns".
    // Other managers (HPA, admission webhooks) own their own fields.
    return r.Client.Patch(ctx, desired,
        client.Apply(),
        client.ForceOwnership(),
        client.FieldOwner("webapp-operator"),
    )
}
```

!!! tip "SSA vs CreateOrUpdate"
    `controllerutil.CreateOrUpdate` is fine for simple cases, but SSA is more robust when:

    - Other controllers (HPA, admission webhooks) also modify the same object
    - You want to avoid the Get-then-Update race condition
    - You're managing objects with many fields you don't own

    The key: populate **only the fields your controller owns**, set a unique `fieldManager`, and use `ForceOwnership()` for fields you're taking over from another manager.

---

## The Multi-Error Pattern

When reconciling multiple sub-resources, don't bail on the first error. Use `errors.Join` (Go 1.20+) to collect all failures:

```go
var errs []error

if err := r.reconcileDeployment(ctx, webapp); err != nil {
    errs = append(errs, fmt.Errorf("deployment: %w", err))
}
if err := r.reconcileService(ctx, webapp); err != nil {
    errs = append(errs, fmt.Errorf("service: %w", err))
}

// errors.Join(nil, nil) returns nil — safe when there are no errors
return ctrl.Result{}, errors.Join(errs...)
```

Why? If Deployment reconciliation fails, you still want to attempt Service reconciliation. Partial progress toward desired state is better than no progress. The combined error causes a requeue for all failures.
