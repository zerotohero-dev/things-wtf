# The Informer Cache — How It Actually Works

When you call `r.Get()` or `r.List()` in your reconciler, you are **not hitting the API server**. You're reading from a local in-memory cache backed by informers. Understanding this is critical for avoiding subtle bugs.

---

## The Informer Pipeline

```text
                        For each watched resource type
┌──────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  ┌──────────────┐  ListWatch   ┌─────────────────┐  events   ┌──────┐│
│  │ API Server   │─────────────▶│    Reflector     │──────────▶│Delta ││
│  │ (etcd-backed)│              │ (List once, then │           │Queue ││
│  └──────────────┘              │  Watch stream)   │           └──┬───┘│
│                                └─────────────────┘             │    │
│                                                                 ▼    │
│              ┌──────────────────────────────────────────────────┐   │
│              │                  Informer                         │   │
│              │  ┌──────────────────┐  ┌──────────────────────┐  │   │
│              │  │  Thread-safe     │  │  Event Handlers      │  │   │
│              │  │  Store           │  │  (your predicates)   │  │   │
│              │  │  ← r.Get() reads │  │  → enqueue key to    │  │   │
│              │  │    from here     │  │    work queue         │  │   │
│              │  └──────────────────┘  └──────────────────────┘  │   │
│              └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

The Reflector does an initial `List` to populate the store, then switches to a `Watch` (long-poll) stream to receive incremental updates. This is why cache sync must complete before reconciliation begins.

---

## The Four Critical Gotchas

### Gotcha 1: The Cache Is Eventually Consistent

!!! warning "r.Get() after r.Create() may return the old state"
    After you call `r.Client.Create()` or `r.Client.Update()`, the cache may not reflect the change immediately. The write path is:

    ```
    r.Create() → etcd write → watch event published → Reflector receives →
    Delta queue → Informer Store updated
    ```

    This is usually sub-second but **never zero**. If you immediately `r.Get()` after a `r.Create()`, you might get `NotFound` or the previous version.

    **Solution:** Don't re-read immediately after writes. Let the next reconcile (triggered by the watch event) do the fresh read.

    ```go
    // PROBLEMATIC — race between create and cache sync
    r.Create(ctx, deployment)
    dep := &appsv1.Deployment{}
    r.Get(ctx, ..., dep) // might get NotFound or stale state

    // CORRECT — return, let watch event trigger next reconcile
    if err := r.Create(ctx, deployment); err != nil {
        return ctrl.Result{}, err
    }
    return ctrl.Result{}, nil // next reconcile will read fresh state
    ```

### Gotcha 2: Never Mutate Objects From the Cache

!!! danger "r.Get() returns a pointer into the cache store"
    The object returned by `r.Get()` is a pointer to the actual object in the cache store. If you mutate it directly — even temporarily for comparison — you **corrupt the cache** for all concurrent readers.

    ```go
    original := &appsv1alpha1.WebApp{}
    r.Get(ctx, req.NamespacedName, original)

    // WRONG — mutates the cache object directly
    original.Status.ReadyReplicas = 3  // ← corrupts cache for all goroutines!

    // CORRECT — always deepcopy before mutating
    modified := original.DeepCopy()
    modified.Status.ReadyReplicas = 3
    r.Status().Update(ctx, modified)
    ```

    This bug is especially insidious because it may work fine in tests (single goroutine) but fail intermittently in production (concurrent reconciles).

### Gotcha 3: Cache Caches Everything By Default

!!! warning "Unscoped cache uses significant memory in large clusters"
    By default, controller-runtime caches all objects of watched types **cluster-wide**. In a large cluster:

    - Watching `corev1.Pod` cluster-wide: could be 10,000+ pods in cache
    - Watching `corev1.ConfigMap` cluster-wide: could be thousands

    Scope your cache to relevant namespaces or label selectors. See [§12 Namespace-Scoped Cache](./12-namespace-scoped-cache.md).

### Gotcha 4: Unregistered Types Bypass Cache

!!! warning "r.Get() for unwatched types goes direct to API server"
    If you call `r.Get()` for a type you haven't registered a watch for (not in `For()`, `Owns()`, or `Watches()`), the client will **bypass the cache and go directly to the API server**. This is:

    - Slower (network round-trip vs memory)
    - Not rate-limited by the controller's rate limiter
    - Won't trigger reconcile when that object changes

    If you're reading a type frequently, register a watch. If it's rare (e.g., bootstrap config read once at startup), the direct read is fine.

---

## The Startup Re-Sync

On every operator restart:

1. All informers perform a full `List` of watched types
2. The cache is populated
3. Every object that passes your predicates is enqueued
4. Your reconcile function runs for every object

This means **every object is reconciled on every operator restart**. This is intentional — it ensures convergence after any outage. Your reconciler must be idempotent because of this.

!!! tip "Startup reconcile storms"
    With many objects, the startup re-sync can create a large queue. The work queue deduplicates (one entry per namespace/name), so if the same object gets enqueued multiple times from the initial list, it's only reconciled once. The rate limiter also throttles the drain rate.

---

## Bypassing the Cache When Needed

Sometimes you genuinely need live API server state — e.g., you created a Service and need its assigned `ClusterIP` immediately. Use `APIReader`:

```go title="cmd/main.go — register APIReader"
// In your reconciler struct
type WebAppReconciler struct {
    client.Client
    APIReader client.Reader  // bypasses cache, goes direct to API server
    Scheme    *runtime.Scheme
}

// In main.go
if err := (&WebAppReconciler{
    Client:    mgr.GetClient(),
    APIReader: mgr.GetAPIReader(), // ← direct reader
    Scheme:    mgr.GetScheme(),
}).SetupWithManager(mgr); err != nil {
    setupLog.Error(err, "unable to create controller")
    os.Exit(1)
}

// In reconcile — use APIReader for freshness-critical reads
freshSvc := &corev1.Service{}
if err := r.APIReader.Get(ctx, types.NamespacedName{...}, freshSvc); err != nil {
    return ctrl.Result{}, err
}
// freshSvc.Spec.ClusterIP is now guaranteed to be the assigned IP
```

Use `APIReader` sparingly — it increases API server load and has no caching benefit.

---

## Cache Debug Tricks

```bash
# Check if informers are synced (via metrics)
kubectl port-forward -n webapp-operator-system svc/webapp-operator-metrics 8080
curl -s http://localhost:8080/metrics | grep 'controller_runtime_reconcile'

# See how many objects are in watch scope
curl -s http://localhost:8080/metrics | grep 'rest_client_requests_total'

# Check controller-runtime's internal cache state via logs
# Set log level to 5+ to see informer sync messages
kubectl set env deployment/webapp-operator-controller-manager \
  -n webapp-operator-system LOGGING_LEVEL=5
```
