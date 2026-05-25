# Watching Secondary Resources

Your operator doesn't just watch its own CR. It also watches the resources it creates (Deployments, Services, etc.) so that if someone manually deletes or modifies them, reconcile fires and desired state is restored.

---

## Watching Owned Resources with `.Owns()`

`.Owns()` watches a resource type and automatically maps events back to the owning CR by looking at `ownerReferences`. This is the standard pattern for secondary resources your controller creates.

```go title="SetupWithManager — Owns pattern"
func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.WebApp{}).
        // Watches Deployments, maps to WebApp via ownerRef.
        // If someone deletes the Deployment, WebApp's reconcile fires immediately.
        Owns(&appsv1.Deployment{},
            builder.WithPredicates(DeploymentStatusChangedPredicate{}),
        ).
        Owns(&corev1.Service{}).
        Owns(&networkingv1.Ingress{}).
        Complete(r)
}
```

**How the mapping works:**

1. Deployment event fires
2. controller-runtime reads `deployment.metadata.ownerReferences`
3. Finds entry where `controller=true`
4. Extracts the owner's namespace/name
5. Enqueues that namespace/name key for reconcile

No custom code needed for this mapping — `.Owns()` handles it automatically.

---

## Watching Unowned / External Resources

Sometimes you need to react to resources you don't own — a shared ConfigMap that many WebApps reference, a Node going NotReady, a Secret being rotated. Use `.Watches()` with a custom `handler.MapFunc`.

### The MapFunc Pattern

```go title="SetupWithManager — watching a shared ConfigMap"
func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    // Register index first so the MapFunc can do fast cache lookups.
    // See §11 Field Indexers for full setup.
    if err := mgr.GetFieldIndexer().IndexField(
        context.Background(),
        &appsv1alpha1.WebApp{},
        ".spec.configMapRef",
        func(obj client.Object) []string {
            webapp := obj.(*appsv1alpha1.WebApp)
            if webapp.Spec.ConfigMapRef == "" {
                return nil
            }
            return []string{webapp.Spec.ConfigMapRef}
        },
    ); err != nil {
        return err
    }

    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.WebApp{}).
        Owns(&appsv1.Deployment{}).
        // Watch ConfigMaps that WebApps reference.
        // When a ConfigMap changes, reconcile all WebApps that reference it.
        Watches(
            &corev1.ConfigMap{},
            handler.EnqueueRequestsFromMapFunc(r.findWebAppsForConfigMap),
            builder.WithPredicates(predicate.ResourceVersionChangedPredicate{}),
        ).
        Complete(r)
}

// findWebAppsForConfigMap is the MapFunc — given a ConfigMap, return the
// list of WebApp reconcile requests.
func (r *WebAppReconciler) findWebAppsForConfigMap(
    ctx context.Context,
    obj client.Object,
) []reconcile.Request {
    // Use the field index for an efficient O(1) lookup.
    // NEVER do an unindexed List here — it scans all objects.
    list := &appsv1alpha1.WebAppList{}
    if err := r.List(ctx, list,
        client.InNamespace(obj.GetNamespace()),
        client.MatchingFields{".spec.configMapRef": obj.GetName()},
    ); err != nil {
        // Cannot return error from MapFunc — log and return empty
        log.FromContext(ctx).Error(err, "listing WebApps for ConfigMap")
        return nil
    }

    reqs := make([]reconcile.Request, len(list.Items))
    for i, wa := range list.Items {
        reqs[i] = reconcile.Request{
            NamespacedName: types.NamespacedName{
                Namespace: wa.Namespace,
                Name:      wa.Name,
            },
        }
    }
    return reqs
}
```

!!! danger "MapFunc must be fast — no API calls, no blocking"
    The MapFunc runs in the informer goroutine. If it blocks, panics, or makes API calls, it can stall your entire watch stream. It should **only** do cache lookups (via indexed fields). If the lookup fails, return `nil` (no reconcile) and log the error.

---

## Watching Cluster-Scoped Resources

When watching a cluster-scoped resource (Node, Namespace, ClusterRole) to trigger namespace-scoped reconciles, you need a MapFunc that fans out:

```go
// When ANY Node changes, reconcile all WebApps on that node
Watches(
    &corev1.Node{},
    handler.EnqueueRequestsFromMapFunc(func(ctx context.Context, obj client.Object) []reconcile.Request {
        // Find all WebApps that have pods scheduled on this node
        // (requires a "pod.spec.nodeName" index on WebApp or a lookup via pods)
        pods := &corev1.PodList{}
        if err := r.List(ctx, pods,
            client.MatchingFields{".spec.nodeName": obj.GetName()},
        ); err != nil {
            return nil
        }
        // ... map pods back to WebApps via owner references ...
        return requests
    }),
    builder.WithPredicates(
        predicate.NewPredicateFuncs(func(obj client.Object) bool {
            node := obj.(*corev1.Node)
            // Only care about NotReady transitions
            for _, c := range node.Status.Conditions {
                if c.Type == corev1.NodeReady && c.Status == corev1.ConditionFalse {
                    return true
                }
            }
            return false
        }),
    ),
),
```

---

## Watching with a Channel Source

For external triggers (webhooks, timers, external queue messages), you can inject events directly into the work queue via a channel:

```go
// Create a channel that feeds synthetic events
eventCh := make(chan event.GenericEvent)

ctrl.NewControllerManagedBy(mgr).
    For(&appsv1alpha1.WebApp{}).
    // Feed from external channel — each event must contain the object to reconcile
    WatchesRawSource(source.Channel(eventCh, handler.EnqueueRequestForObject{})).
    Complete(r)

// From your goroutine / webhook / timer:
eventCh <- event.GenericEvent{
    Object: &appsv1alpha1.WebApp{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "my-app",
            Namespace: "production",
        },
    },
}
```

---

## Avoiding Watch Amplification

!!! warning "A single external resource change can trigger many reconciles"
    If 500 WebApps all reference the same ConfigMap, one ConfigMap change triggers 500 reconcile requests. This is usually fine (they're deduplicated per-key in the queue), but be aware of the math.

    Mitigations:
    - Add good predicates to the ConfigMap watch (don't trigger on every metadata change)
    - Use `MaxConcurrentReconciles` > 1 to drain the queue faster
    - Design your CRD so that "shared config" changes are rare

---

## Watching Multiple Types in One Controller

```go
ctrl.NewControllerManagedBy(mgr).
    For(&appsv1alpha1.WebApp{}).
    Owns(&appsv1.Deployment{}).
    Owns(&corev1.Service{}).
    Owns(&networkingv1.Ingress{}).
    Watches(&corev1.ConfigMap{}, handler.EnqueueRequestsFromMapFunc(r.mapConfigMap)).
    Watches(&corev1.Secret{},    handler.EnqueueRequestsFromMapFunc(r.mapSecret)).
    Complete(r)
```

Each `Watches()` and `Owns()` call creates a separate informer. If you're watching 10 resource types cluster-wide, you have 10 informers running — each doing a List on startup and maintaining a watch stream. In large clusters, be selective about what you watch and use namespace/label scoping (see [§12](../cache/12-namespace-scoped-cache.md)).
