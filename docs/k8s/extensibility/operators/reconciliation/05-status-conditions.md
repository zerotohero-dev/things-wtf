# Status & Conditions

Status is how your operator communicates observed reality back to users and tooling. The **Conditions** pattern (from Kubernetes itself) is the standard way — it's machine-readable, composable, and supports `kubectl wait`.

---

## Condition Structure

Each condition has:

| Field | Type | Example |
|-------|------|---------|
| `Type` | string | `Available`, `Progressing`, `Degraded` |
| `Status` | `True` / `False` / `Unknown` | `True` |
| `Reason` | string (CamelCase, machine-readable) | `DeploymentReady` |
| `Message` | string (human-readable) | `3/3 replicas ready` |
| `ObservedGeneration` | int64 | `7` |
| `LastTransitionTime` | metav1.Time | auto-set by `meta.SetStatusCondition` |

---

## Implementing Status Updates

```go title="internal/controller/webapp_controller.go"
const (
    ConditionAvailable   = "Available"
    ConditionProgressing = "Progressing"
    ConditionDegraded    = "Degraded"

    ReasonDeploymentReady    = "DeploymentReady"
    ReasonDeploymentNotReady = "DeploymentNotReady"
    ReasonReconciling        = "Reconciling"
)

func (r *WebAppReconciler) updateStatus(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    // Fetch the current Deployment to derive status from actual state
    dep := &appsv1.Deployment{}
    depErr := r.Get(ctx, types.NamespacedName{
        Namespace: webapp.Namespace,
        Name:      webapp.Name,
    }, dep)

    // Always update ObservedGeneration. This lets users and tooling know
    // which spec version has been processed.
    // Compare spec.generation vs status.observedGeneration to detect lag.
    webapp.Status.ObservedGeneration = webapp.Generation

    switch {
    case depErr != nil && !apierrors.IsNotFound(depErr):
        meta.SetStatusCondition(&webapp.Status.Conditions, metav1.Condition{
            Type:               ConditionAvailable,
            Status:             metav1.ConditionUnknown,
            ObservedGeneration: webapp.Generation,
            Reason:             "FetchError",
            Message:            fmt.Sprintf("Cannot fetch deployment: %v", depErr),
        })

    case apierrors.IsNotFound(depErr):
        meta.SetStatusCondition(&webapp.Status.Conditions, metav1.Condition{
            Type:               ConditionAvailable,
            Status:             metav1.ConditionFalse,
            ObservedGeneration: webapp.Generation,
            Reason:             ReasonReconciling,
            Message:            "Deployment not yet created",
        })

    default:
        webapp.Status.ReadyReplicas = dep.Status.ReadyReplicas
        desired := dep.Spec.Replicas
        if desired == nil {
            d := int32(1)
            desired = &d
        }

        if dep.Status.ReadyReplicas == *desired && dep.Status.ReadyReplicas > 0 {
            meta.SetStatusCondition(&webapp.Status.Conditions, metav1.Condition{
                Type:               ConditionAvailable,
                Status:             metav1.ConditionTrue,
                ObservedGeneration: webapp.Generation,
                Reason:             ReasonDeploymentReady,
                Message:            fmt.Sprintf("%d/%d replicas ready", dep.Status.ReadyReplicas, *desired),
            })
        } else {
            meta.SetStatusCondition(&webapp.Status.Conditions, metav1.Condition{
                Type:               ConditionAvailable,
                Status:             metav1.ConditionFalse,
                ObservedGeneration: webapp.Generation,
                Reason:             ReasonDeploymentNotReady,
                Message:            fmt.Sprintf("%d/%d replicas ready", dep.Status.ReadyReplicas, *desired),
            })
        }
    }

    // IMPORTANT: Use r.Status().Update(), NOT r.Update()
    return r.Status().Update(ctx, webapp)
}
```

---

## The Status Update Gotchas

!!! danger "Use r.Status().Update(), not r.Update()"
    When the status subresource is enabled, calling `r.Update()` with a modified `.status` will **silently drop the status changes**. The spec will be saved, the status will not. Use `r.Status().Update()`.

!!! warning "Avoid the status-update infinite loop"
    If you update status in every reconcile, and every status update triggers another reconcile (because status changes fire a watch event), you get an infinite loop.

    Two mitigations:

    **1. Compare before updating:**
    ```go
    // Only call Status().Update() if something actually changed
    if !reflect.DeepEqual(existingStatus, newStatus) {
        return r.Status().Update(ctx, webapp)
    }
    ```

    **2. Use GenerationChangedPredicate:**
    ```go
    // This predicate drops status-only updates from triggering reconcile
    builder.WithPredicates(predicate.GenerationChangedPredicate{})
    ```

    Using `GenerationChangedPredicate` on your `For()` watch is the cleaner solution — status updates don't increment `metadata.generation`, so they're filtered out entirely.

!!! warning "Conflict on Status().Update()"
    Status updates can conflict if another reconcile (or external tool) updated status between your fetch and your write. Handle it by returning an error (which triggers a requeue with fresh state):

    ```go
    if err := r.Status().Update(ctx, webapp); err != nil {
        if apierrors.IsConflict(err) {
            // Another writer beat us — requeue, re-fetch, re-compute
            return ctrl.Result{}, err
        }
        return ctrl.Result{}, fmt.Errorf("updating status: %w", err)
    }
    ```

---

## ObservedGeneration — Why It Matters

`status.observedGeneration` tells users (and GitOps tools) which version of the spec has been processed:

```bash
# Spec was updated (generation bumped to 5)
$ kubectl get webapp my-app -o jsonpath='{.metadata.generation}'
5

# Controller hasn't processed it yet
$ kubectl get webapp my-app -o jsonpath='{.status.observedGeneration}'
4

# Wait until processed
$ kubectl wait webapp my-app \
  --for=jsonpath='{.status.observedGeneration}'=5 \
  --timeout=60s
```

Your operator should always set `status.observedGeneration = metadata.generation` at the start of the status update, before any other status fields.

---

## Using kubectl wait with Conditions

Conditions enable clean automation:

```bash
# Wait for the WebApp to be Available
kubectl wait webapp my-app \
  --for=condition=Available \
  --timeout=120s

# Wait for Available=True with specific reason (kubectl 1.27+)
kubectl wait webapp my-app \
  --for=condition=Available=True \
  --timeout=120s
```

This is why using `metav1.Condition` (not custom boolean fields) matters — it integrates with standard Kubernetes tooling.

---

## Status Patch vs Update

For status updates, prefer `Patch` over `Update` to minimize conflict risk:

```go
// Capture baseline BEFORE you make changes
base := webapp.DeepCopy()

// Make your status changes
webapp.Status.ReadyReplicas = dep.Status.ReadyReplicas
meta.SetStatusCondition(&webapp.Status.Conditions, ...)

// Patch only the diff — less likely to conflict than a full update
return r.Status().Patch(ctx, webapp, client.MergeFrom(base))
```
