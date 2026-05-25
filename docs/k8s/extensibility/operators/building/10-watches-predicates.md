# 10 · Watches & Predicates

By default, a reconciler is triggered whenever *any* change happens to its primary
resource. That's often too broad. **Predicates** filter events before they hit the
work queue, reducing unnecessary reconciles.

---

## SetupWithManager with full watch config

```go
func (r *SpikeConfigReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        // For(): primary resource.
        // GenerationChangedPredicate: only trigger if spec changed.
        // Status updates do NOT increment generation, so they won't
        // cause re-reconcile. This breaks the feedback loop.
        For(&spikev1alpha1.SpikeConfig{},
            builder.WithPredicates(predicate.GenerationChangedPredicate{}),
        ).

        // Owns(): if an owned Secret is modified or deleted, enqueue parent.
        // This is how you detect and repair configuration drift.
        Owns(&corev1.Secret{}).

        // Watches(): arbitrary resource with a custom enqueue handler.
        // When a specific ConfigMap changes, reconcile all SpikeConfigs.
        Watches(
            &corev1.ConfigMap{},
            handler.EnqueueRequestsFromMapFunc(r.findSpikeConfigsForConfigMap),
            builder.WithPredicates(
                predicate.And(
                    predicate.ResourceVersionChangedPredicate{},
                    predicate.NewPredicateFuncs(func(obj client.Object) bool {
                        return obj.GetName() == "spike-global-config"
                    }),
                ),
            ),
        ).

        WithOptions(controller.Options{
            MaxConcurrentReconciles: 5,
        }).
        Complete(r)
}

// Given a changed ConfigMap, return the SpikeConfig keys to reconcile.
func (r *SpikeConfigReconciler) findSpikeConfigsForConfigMap(
    ctx context.Context,
    obj client.Object,
) []reconcile.Request {
    var scList spikev1alpha1.SpikeConfigList
    if err := r.List(ctx, &scList); err != nil {
        return nil
    }
    requests := make([]reconcile.Request, len(scList.Items))
    for i, sc := range scList.Items {
        requests[i] = reconcile.Request{
            NamespacedName: types.NamespacedName{
                Namespace: sc.Namespace,
                Name:      sc.Name,
            },
        }
    }
    return requests
}
```

---

## Predicate reference

| Predicate | Triggers on | Use when |
|---|---|---|
| `GenerationChangedPredicate` | Spec changes only | Primary resource — avoids status-update loops |
| `ResourceVersionChangedPredicate` | Any real change | Owned resources, ConfigMaps, Secrets you watch |
| `LabelChangedPredicate` | Label changes | Label-selector-based logic |
| `AnnotationChangedPredicate` | Annotation changes | Manual "kick" annotations |
| `predicate.NewPredicateFuncs(fn)` | Custom function | Filter by name, namespace, content |
| `predicate.And(a, b)` | Both a AND b | Compose multiple conditions |
| `predicate.Or(a, b)` | Either a OR b | Alternative triggers |

---

## The status feedback loop — the most common predicate mistake

!!! danger "Critical: always use GenerationChangedPredicate on For()"

    If you watch your primary resource without `GenerationChangedPredicate`,
    and your reconciler calls `r.Status().Patch()`, this sequence happens:

    1. `r.Status().Patch()` writes status → fires a watch event
    2. Watch event enqueues the object
    3. Reconciler runs → calls `r.Status().Patch()` again → fires another watch event
    4. ↑ repeat forever

    Always use `GenerationChangedPredicate` on `For()` for any resource where
    your reconciler touches status.

---

## Custom predicates

You can implement the `predicate.Funcs` interface for fine-grained control:

```go
type HasManagedByAnnotation struct {
    predicate.Funcs
    AnnotationValue string
}

func (p HasManagedByAnnotation) Create(e event.CreateEvent) bool {
    return e.Object.GetAnnotations()["managed-by"] == p.AnnotationValue
}

func (p HasManagedByAnnotation) Update(e event.UpdateEvent) bool {
    return e.ObjectNew.GetAnnotations()["managed-by"] == p.AnnotationValue
}

// Delete and Generic inherit the default (true) from predicate.Funcs
```

Use custom predicates when you need to filter on content, annotations, labels, or
computed properties that the built-in predicates don't cover.
