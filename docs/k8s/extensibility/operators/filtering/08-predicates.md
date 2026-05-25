# Predicates — Filtering What Triggers Reconcile

Every watch event (Create, Update, Delete, Generic) passes through your predicates before hitting the work queue. If a predicate returns `false`, the event is **dropped** — reconcile is never called. This is critical for performance: without good predicates, a busy cluster generates enormous amounts of unnecessary reconcile calls.

!!! info "Where predicates run"
    Predicates run in the informer's event handler goroutine. They must be **fast and non-blocking** — no API calls, no mutexes, no I/O. A slow predicate stalls your entire watch stream.

---

## Attaching Predicates

```go title="internal/controller/webapp_controller.go — SetupWithManager"
func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.WebApp{},
            // Only reconcile when spec changes (generation increments).
            // Drops all status updates and metadata-only changes.
            builder.WithPredicates(predicate.GenerationChangedPredicate{}),
        ).
        Owns(&appsv1.Deployment{},
            builder.WithPredicates(DeploymentStatusChangedPredicate{}),
        ).
        Owns(&corev1.Service{}).
        Owns(&networkingv1.Ingress{}).
        Complete(r)
}
```

---

## Built-in Predicates

| Predicate | Passes when | Notes |
|-----------|------------|-------|
| `GenerationChangedPredicate` | `metadata.generation` changed | Spec-only changes. **Most important predicate.** Drops all status updates. |
| `ResourceVersionChangedPredicate` | Any change (spec, status, metadata) | Allows status updates through. Good for owned resources. |
| `LabelChangedPredicate` | Labels changed | Good for label-gated resources |
| `AnnotationChangedPredicate` | Annotations changed | Useful when annotation drives behavior |
| `Not(p)` | `p` returns false | Inverts a predicate |
| `And(p1, p2)` | Both return true | All must pass |
| `Or(p1, p2)` | Either returns true | Any one passing is sufficient |

### GenerationChangedPredicate Warning

!!! warning "GenerationChangedPredicate doesn't work for all types"
    `GenerationChangedPredicate` checks `metadata.generation`, which is only incremented on `.spec` changes — and **only for types that have a spec**. Some types do not increment generation at all:

    - `ConfigMap` — every update bumps `resourceVersion` but NOT `generation`
    - `Secret` — same
    - `ServiceAccount` — same

    For these types, use `ResourceVersionChangedPredicate` or a custom predicate that compares the relevant fields.

---

## Custom Predicates

### By Label Value

```go title="internal/controller/predicates.go"
package controller

import (
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/event"
    "sigs.k8s.io/controller-runtime/pkg/predicate"
)

// HasLabelPredicate passes only objects with a specific label key+value.
type HasLabelPredicate struct {
    Key   string
    Value string
}

func (p HasLabelPredicate) Create(e event.CreateEvent) bool {
    return hasLabel(e.Object, p.Key, p.Value)
}

func (p HasLabelPredicate) Update(e event.UpdateEvent) bool {
    // Check BOTH old and new state.
    // If label was removed: old=true, new=false → we want to reconcile (handle removal).
    // If label was added: old=false, new=true → we want to reconcile (new match).
    return hasLabel(e.ObjectNew, p.Key, p.Value) || hasLabel(e.ObjectOld, p.Key, p.Value)
}

func (p HasLabelPredicate) Delete(e event.DeleteEvent) bool {
    return hasLabel(e.Object, p.Key, p.Value)
}

func (p HasLabelPredicate) Generic(e event.GenericEvent) bool { return true }

func hasLabel(obj client.Object, key, val string) bool {
    labels := obj.GetLabels()
    if labels == nil {
        return false
    }
    v, ok := labels[key]
    return ok && v == val
}
```

### Deployment Status Changed

```go
// DeploymentStatusChangedPredicate: only passes when deployment's
// ready/available replica counts change. Avoids reconciling for
// metadata-only changes to owned Deployments.
type DeploymentStatusChangedPredicate struct {
    predicate.Funcs // embed defaults: Create/Delete/Generic return true
}

func (p DeploymentStatusChangedPredicate) Update(e event.UpdateEvent) bool {
    oldDep, ok1 := e.ObjectOld.(*appsv1.Deployment)
    newDep, ok2 := e.ObjectNew.(*appsv1.Deployment)
    if !ok1 || !ok2 {
        return true // can't determine — allow through
    }
    return oldDep.Status.ReadyReplicas != newDep.Status.ReadyReplicas ||
        oldDep.Status.AvailableReplicas != newDep.Status.AvailableReplicas ||
        oldDep.Generation != newDep.Generation
}
```

### Functional One-Liner

For simple cases, use `predicate.NewPredicateFuncs`:

```go
// Only reconcile ConfigMaps with our label
builder.WithPredicates(
    predicate.NewPredicateFuncs(func(obj client.Object) bool {
        return obj.GetLabels()["managed-by"] == "webapp-operator"
    }),
)
```

!!! tip "`predicate.NewPredicateFuncs` applies the same function to Create, Update, Delete, and Generic"
    It's a quick shortcut. For Update events where you need to compare old vs new, implement the full `predicate.Predicate` interface like `HasLabelPredicate` above.

---

## Composing Predicates

```go
// Reconcile when: spec changed OR annotation changed
builder.WithPredicates(predicate.Or(
    predicate.GenerationChangedPredicate{},
    predicate.AnnotationChangedPredicate{},
))

// Reconcile when: ResourceVersion changed AND has our label
builder.WithPredicates(predicate.And(
    predicate.ResourceVersionChangedPredicate{},
    HasLabelPredicate{Key: "tier", Value: "frontend"},
))
```

---

## Predicate Event Types Cheat Sheet

| Event | When fired | `e.Object` fields |
|-------|-----------|------------------|
| `CreateEvent` | Object is created | `Object` = new object |
| `UpdateEvent` | Object is updated | `ObjectOld` = before, `ObjectNew` = after |
| `DeleteEvent` | Object is deleted | `Object` = last known state, `DeleteStateUnknown` flag |
| `GenericEvent` | External trigger (e.g., from `channel.Source`) | `Object` = current |

The `DeleteStateUnknown` flag in `DeleteEvent` is set when the informer missed the delete and is synthesizing it from a re-list. Your predicate should handle this gracefully (typically: return `true`).
