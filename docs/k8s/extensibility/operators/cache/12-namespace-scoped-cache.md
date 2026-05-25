# Namespace-Scoped Cache

By default, controller-runtime caches objects **cluster-wide**. In a large cluster with thousands of pods and ConfigMaps, this uses significant memory and adds startup latency. Scope the cache when possible.

---

## Namespace-Restricted Cache

```go title="cmd/main.go"
import (
    "sigs.k8s.io/controller-runtime/pkg/cache"
)

mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
    Scheme: scheme,

    // Only cache objects in specific namespaces.
    // Objects outside these namespaces won't be in cache — r.Get() for them
    // will go direct to API server (and return NotFound from cache perspective).
    Cache: cache.Options{
        DefaultNamespaces: map[string]cache.Config{
            "production": {},
            "staging":    {},
        },
    },
})
```

---

## Per-Type Cache Configuration

You can apply different scoping rules per object type:

```go title="cmd/main.go — per-type cache config"
mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
    Cache: cache.Options{
        // Default: watch all namespaces
        // But for Secrets — only cache ones with our label
        ByObject: map[client.Object]cache.ByObject{
            &corev1.Secret{}: {
                Label: labels.SelectorFromSet(labels.Set{
                    "managed-by": "webapp-operator",
                }),
            },
            // Only cache Pods in our namespace
            &corev1.Pod{}: {
                Namespaces: map[string]cache.Config{
                    "webapp-operator-system": {},
                },
            },
        },
    },
})
```

---

## Cache Scope Gotchas

!!! warning "Cache scope affects r.Get() and r.List()"
    If you cache Secrets only with label `managed-by: webapp-operator`, then:

    - `r.Get()` on a Secret **without** that label returns `NotFound` (from cache)
    - `r.List()` on Secrets returns **only** labeled Secrets

    This can cause very confusing bugs: the Secret exists in Kubernetes, but your controller says it doesn't. Make sure the cache scope matches what your reconciler actually needs.

!!! warning "Namespace-scoped cache requires RBAC scoped to those namespaces"
    If you restrict the cache to specific namespaces, your operator's RBAC must also be scoped accordingly. A `ClusterRole` with cluster-wide permissions still works, but if you're scoping RBAC to a `RoleBinding` per namespace, ensure each watched namespace is covered.

---

## Cluster-Scoped Resources Always Cache Cluster-Wide

Cluster-scoped resources (Nodes, Namespaces, ClusterRoles, PersistentVolumes) are always cached cluster-wide regardless of `DefaultNamespaces` settings. Namespace restrictions only apply to namespace-scoped resources.

```go
// This has no effect on Nodes — they're cluster-scoped
Cache: cache.Options{
    ByObject: map[client.Object]cache.ByObject{
        &corev1.Node{}: {
            // Namespace restrictions are ignored for cluster-scoped types
            Namespaces: map[string]cache.Config{
                "production": {},
            },
        },
    },
},
```

---

## Multi-Namespace Operator Pattern

For operators that manage resources across many namespaces dynamically (e.g., a platform operator that watches all tenant namespaces), a cluster-wide cache is often necessary. In that case, use label selector scoping to limit memory:

```go
Cache: cache.Options{
    ByObject: map[client.Object]cache.ByObject{
        // Only cache WebApps — our primary resource, all namespaces
        &appsv1alpha1.WebApp{}: {},
        // Only cache Deployments we own
        &appsv1.Deployment{}: {
            Label: labels.SelectorFromSet(labels.Set{
                "app.kubernetes.io/managed-by": "webapp-operator",
            }),
        },
        // Only cache Services we own
        &corev1.Service{}: {
            Label: labels.SelectorFromSet(labels.Set{
                "app.kubernetes.io/managed-by": "webapp-operator",
            }),
        },
    },
},
```

!!! tip "Always label your owned resources"
    Label every resource you create with `app.kubernetes.io/managed-by: your-operator-name`. This enables cache scoping, makes debugging easier (`kubectl get all -l app.kubernetes.io/managed-by=webapp-operator`), and is a Kubernetes best practice.
