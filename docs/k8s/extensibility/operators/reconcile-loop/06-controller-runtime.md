# 06 · controller-runtime Internals

`controller-runtime` is the library underneath kubebuilder and Operator SDK.
Understanding its architecture helps you reason about performance, debugging,
and concurrency.

---

## The Manager

The **Manager** is the root object. It owns the shared cache, the client, the
scheme, and all controllers. You call `mgr.Start(ctx)` and it blocks, running
everything. All controllers in a manager share one cache.

Key components owned by the Manager:

| Component | Role |
|---|---|
| **Scheme** | Registry mapping GVKs to Go types |
| **Cache** | Shared informers per GVK; backs all `r.Get()` / `r.List()` calls |
| **Client** | Cache-backed for reads; direct API server for writes |
| **Controllers** | Each has its own watches and work queue |
| **Webhook server** | Optional; serves mutating/validating webhooks over TLS |
| **Metrics server** | Exposes Prometheus metrics at `:8080/metrics` |
| **Health server** | Exposes `/healthz` and `/readyz` |

---

## The shared informer cache

This is perhaps the most important thing to understand for debugging. **All
controllers in a Manager share one cache per resource type.** When Controller A
and Controller B both watch Secrets, there is only one Secret informer — one
list-watch stream to the API server, one in-memory store.

This is efficient, but it means: **reads via `r.Get()` and `r.List()` hit the
cache, not the API server.** The cache is eventually consistent with etcd.
After you write an object, the cache may not reflect your write immediately.

```go
// Cache-backed read (default). Fast, but may be slightly stale.
var secret corev1.Secret
err := r.Get(ctx, key, &secret)

// Direct API server read. Use sparingly — bypasses cache, adds API server load.
// Inject this in your struct as APIReader client.Reader
var secret corev1.Secret
err := r.APIReader.Get(ctx, key, &secret)
```

!!! warning "After-write reads"

    If you write an object and immediately `r.Get()` it, you might get the old
    version. Work from the object you just patched rather than re-fetching it.
    If you truly need a live read, use `APIReader`.

---

## The work queue: deduplication and rate limiting

Between the informer cache and the reconciler sits the work queue. It provides
two critical properties:

**Deduplication**: If 100 events fire for `default/my-config` before the
reconciler processes one, the queue holds only *one* entry for that key. You
never process the same key twice concurrently.

**Rate limiting**: On error, keys are requeued with exponential backoff — starting
at ~5ms and growing to ~1000s. This prevents a broken reconciler from hammering
the API server.

!!! tip "The kitchen ticket analogy"

    The work queue is like a kitchen ticket system. If a customer changes their
    order three times before the chef starts cooking, the chef only sees the final
    order — not three separate change events. The queue collapses them. This is
    why your reconciler must always read *current state* from the cache rather
    than reacting to what event was fired.

---

## The informer List-Watch protocol

??? example "Deep dive: how the informer cache stays in sync"

    Informers use a two-phase protocol to sync with the API server:

    **Phase 1 — List**: On startup (and on reconnect), the informer does a full
    `List` of all objects of the watched type. This populates the local cache.
    The response includes a `resourceVersion` — a cursor into the etcd change
    history.

    **Phase 2 — Watch**: The informer opens a persistent HTTP/2 watch stream
    starting from that `resourceVersion`. The API server streams
    `ADDED/MODIFIED/DELETED` events as changes occur in etcd. If the watch
    stream disconnects (network blip, API server restart), the informer reconnects
    and, if the cursor is still valid (etcd retains history for ~5 minutes by
    default), resumes from where it left off. If the cursor has expired, it falls
    back to a full re-List.

    The informer cache uses a `ThreadSafeStore` internally — a concurrent
    in-memory map. All cache reads are lockless using a snapshot, so your
    reconciler reading from the cache is very fast (no network, no lock contention
    for most reads).

---

## Controller wiring: what SetupWithManager does

```go
func (r *SpikeConfigReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        // Primary resource: reconcile whenever SpikeConfig changes
        For(&spikev1alpha1.SpikeConfig{}).
        // Owned resources: if an owned Secret changes, enqueue the parent
        Owns(&corev1.Secret{}).
        // Concurrency
        WithOptions(controller.Options{MaxConcurrentReconciles: 3}).
        Complete(r)
}
```

`NewControllerManagedBy` does the following under the hood:

1. Creates a work queue for this controller
2. Registers informers for each watched type with the shared cache
3. Sets up event handlers that translate watch events into queue entries
4. Wires the queue consumer to call `r.Reconcile()` for each dequeued key

You don't manage any of this directly — it's all wired by `SetupWithManager`.
