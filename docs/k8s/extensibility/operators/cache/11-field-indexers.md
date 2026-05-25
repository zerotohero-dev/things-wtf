# Field Indexers — Efficient Cache Lookups

The in-memory cache supports **field indexes** — you define a function that extracts an index key from an object, and the cache maintains a reverse lookup. Without indexes, finding "all WebApps that reference ConfigMap X" requires listing all WebApps and filtering client-side. With an index, it's a single O(1) lookup.

Indexes are essential for your `MapFunc` watchers (see [§09](../filtering/09-watching-secondary.md)) — without them, every ConfigMap change would trigger a full scan of all WebApps.

---

## Registering Indexes

!!! danger "Indexes must be registered before mgr.Start()"
    Indexes can't be added at runtime. Register all indexes in `SetupWithManager` or in `main()` before calling `mgr.Start()`. If you forget and try to use `MatchingFields`, you'll get a runtime error or panic.

```go title="internal/controller/webapp_controller.go — SetupWithManager"
func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    // ── Index 1: WebApps by referenced ConfigMap name ────────────────────
    if err := mgr.GetFieldIndexer().IndexField(
        context.Background(),
        &appsv1alpha1.WebApp{},
        ".spec.configMapRef", // index name — by convention, use the JSONPath
        func(rawObj client.Object) []string {
            webapp := rawObj.(*appsv1alpha1.WebApp)
            if webapp.Spec.ConfigMapRef == "" {
                return nil // not indexed — won't appear in results
            }
            return []string{webapp.Spec.ConfigMapRef}
        },
    ); err != nil {
        return fmt.Errorf("configmap index: %w", err)
    }

    // ── Index 2: Pods by node name ───────────────────────────────────────
    if err := mgr.GetFieldIndexer().IndexField(
        context.Background(),
        &corev1.Pod{},
        ".spec.nodeName",
        func(rawObj client.Object) []string {
            pod := rawObj.(*corev1.Pod)
            if pod.Spec.NodeName == "" {
                return nil
            }
            return []string{pod.Spec.NodeName}
        },
    ); err != nil {
        return fmt.Errorf("pod node index: %w", err)
    }

    // ── Index 3: Multi-value index — WebApps by all referenced Secrets ───
    // An object can have multiple index entries (one per secret reference)
    if err := mgr.GetFieldIndexer().IndexField(
        context.Background(),
        &appsv1alpha1.WebApp{},
        ".spec.secretRefs",
        func(rawObj client.Object) []string {
            webapp := rawObj.(*appsv1alpha1.WebApp)
            refs := make([]string, 0, len(webapp.Spec.SecretRefs))
            for _, ref := range webapp.Spec.SecretRefs {
                refs = append(refs, ref.Name)
            }
            return refs // can return multiple values — indexed under each
        },
    ); err != nil {
        return fmt.Errorf("secret refs index: %w", err)
    }

    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.WebApp{}).
        // ...
        Complete(r)
}
```

---

## Using Indexes in Queries

```go
// Find all WebApps in "production" that reference ConfigMap "app-config"
webapps := &appsv1alpha1.WebAppList{}
if err := r.List(ctx, webapps,
    client.InNamespace("production"),
    client.MatchingFields{".spec.configMapRef": "app-config"},
); err != nil {
    return err
}
// webapps.Items contains exactly the matching objects — O(1) lookup

// You can combine MatchingFields with MatchingLabels
if err := r.List(ctx, webapps,
    client.InNamespace("production"),
    client.MatchingFields{".spec.configMapRef": "app-config"},
    client.MatchingLabels{"tier": "frontend"},
); err != nil {
    return err
}
```

---

## Index Function Rules

!!! warning "Index functions must be pure, fast, and nil-safe"
    The index function is called on every object during cache sync and on every update. It must be:

    - **Pure** — no side effects, no API calls, no logging
    - **Fast** — no I/O, no computation heavier than a field access
    - **Nil-safe** — handle zero/nil values gracefully

    ```go
    // WRONG — returns "" for unset fields, indexing them under empty string
    func(rawObj client.Object) []string {
        webapp := rawObj.(*appsv1alpha1.WebApp)
        return []string{webapp.Spec.ConfigMapRef} // returns "" if unset!
    }

    // CORRECT — return nil to exclude from index
    func(rawObj client.Object) []string {
        webapp := rawObj.(*appsv1alpha1.WebApp)
        if webapp.Spec.ConfigMapRef == "" {
            return nil // excluded from index
        }
        return []string{webapp.Spec.ConfigMapRef}
    }
    ```

    Returning `nil` means "don't index this object" — it won't appear in query results. Returning `[]string{""}` indexes the object under the empty string, which matches any query for `""`. That's almost always wrong.

---

## Index Naming Conventions

| Convention | Example | Notes |
|-----------|---------|-------|
| JSONPath-style | `.spec.configMapRef` | Most common, matches the field path |
| Dot-prefixed | `.spec.secretRefs` | The leading dot helps distinguish from real JSON keys |
| Namespaced | `apps.example.com/configMapRef` | If multiple controllers share the same cache type |

The name is opaque to Kubernetes — it's just the key you use in `client.MatchingFields{}`. Pick something that's self-documenting.

---

## Indexes Are Per-Cache-Instance

If you have multiple managers in one process (rare but possible), each has its own cache and its own indexes. Indexes registered in one manager's cache are not visible to another manager's client.

In practice, you have one manager per operator binary, so this doesn't come up — but it explains why indexes are registered on `mgr.GetFieldIndexer()` rather than globally.
