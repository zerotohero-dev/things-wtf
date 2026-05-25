# Controllers & Informers

A controller is a reconciliation loop. The canonical Go implementation uses client-go's informer/lister/workqueue stack, typically via controller-runtime.

## The informer pipeline

```
API server (etcd watch stream)
    │
    ▼
Reflector
  • Issues initial LIST, then WATCH
  • Handles 410 Gone: re-lists and re-watches
  • Pushes (event-type, object) pairs into DeltaFIFO
    │
    ▼
DeltaFIFO queue
  • Accumulates deltas: Added, Modified, Deleted, Replaced, Sync
  • Deduplicates: multiple updates to same object before processing → one entry
    │
    ▼
Indexer (thread-safe in-memory store)
  • Updated atomically on each DeltaFIFO pop
  • Supports label-based queries via indices
  • All reads in the reconcile loop come from here — never the API server
    │
    ▼
Event handlers (AddFunc, UpdateFunc, DeleteFunc)
  • Registered by the controller
  • Extract the key (namespace/name) and enqueue it
    │
    ▼
RateLimitingWorkQueue
  • Deduplicating: same key enqueued N times → processed once
  • Rate-limited: base 5ms, exponential backoff up to 1000s on failure
  • Thread-safe: multiple worker goroutines drain it
    │
    ▼
Worker goroutines (n workers, default varies)
  • Pop key from queue
  • Call Reconcile(key)
  • On error: requeue with backoff
  • On success: mark done, remove from queue
```

Key insight: **every read in the reconcile loop uses the local Indexer cache**. The controller adds zero read load to the API server, regardless of how fast it reconciles or how many replicas run.

## The reconcile loop

The pattern all controllers follow:

```go
func (r *FooReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // 1. Fetch the object from cache (never fails due to not-found — that's normal)
    foo := &examplev1.Foo{}
    if err := r.Get(ctx, req.NamespacedName, foo); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // 2. Handle deletion (if finalizer is present)
    if !foo.DeletionTimestamp.IsZero() {
        return r.reconcileDelete(ctx, foo)
    }

    // 3. Ensure finalizer
    if !controllerutil.ContainsFinalizer(foo, myFinalizer) {
        controllerutil.AddFinalizer(foo, myFinalizer)
        return ctrl.Result{}, r.Update(ctx, foo)
    }

    // 4. Compute desired state and reconcile child resources
    if err := r.reconcileDeployment(ctx, foo); err != nil {
        // Don't wrap the error — controller-runtime logs it and requeues
        return ctrl.Result{}, err
    }
    if err := r.reconcileService(ctx, foo); err != nil {
        return ctrl.Result{}, err
    }

    // 5. Update status to reflect observed state
    foo.Status.ObservedGeneration = foo.Generation
    foo.Status.Phase = r.computePhase(foo)
    setCondition(&foo.Status.Conditions, metav1.Condition{
        Type:               "Ready",
        Status:             metav1.ConditionTrue,
        Reason:             "Reconciled",
        ObservedGeneration: foo.Generation,
    })
    if err := r.Status().Update(ctx, foo); err != nil {
        return ctrl.Result{}, err
    }

    // 6. Schedule periodic recheck (optional)
    return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}
```

### Result semantics

| Return value | Effect |
|---|---|
| `ctrl.Result{}, nil` | Done. Requeue only on next watch event. |
| `ctrl.Result{}, err` | Requeue with exponential backoff. Error is logged. |
| `ctrl.Result{Requeue: true}, nil` | Requeue immediately (rate-limited). |
| `ctrl.Result{RequeueAfter: d}, nil` | Requeue after duration `d`. |

Use `RequeueAfter` for resources that need periodic re-checking independent of watch events (certificate expiry, external resource polling).

## Ownership & garbage collection

When a controller creates a child resource, it sets an owner reference on it:

```go
func (r *FooReconciler) reconcileDeployment(ctx context.Context, foo *examplev1.Foo) error {
    deploy := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      foo.Name,
            Namespace: foo.Namespace,
        },
        Spec: buildDeploymentSpec(foo),
    }

    // Set owner reference — GC will delete deploy when foo is deleted
    if err := ctrl.SetControllerReference(foo, deploy, r.Scheme); err != nil {
        return err
    }

    // Create-or-update pattern
    existing := &appsv1.Deployment{}
    err := r.Get(ctx, client.ObjectKeyFromObject(deploy), existing)
    if apierrors.IsNotFound(err) {
        return r.Create(ctx, deploy)
    }
    if err != nil {
        return err
    }

    // Merge desired state into existing
    existing.Spec = deploy.Spec
    return r.Update(ctx, existing)
}
```

`ctrl.SetControllerReference` sets `ownerReferences` with `controller: true`. The GC controller in kube-controller-manager watches for orphaned objects (owner doesn't exist) and deletes them.

## Conditions

The standard pattern for status reporting. Always use `metav1.Condition` (not custom types):

```go
type FooStatus struct {
    Phase              string             `json:"phase,omitempty"`
    ObservedGeneration int64              `json:"observedGeneration,omitempty"`
    Conditions         []metav1.Condition `json:"conditions,omitempty"`
}
```

```go
// apimachinery/pkg/api/meta provides helpers:
meta.SetStatusCondition(&foo.Status.Conditions, metav1.Condition{
    Type:               "Ready",
    Status:             metav1.ConditionTrue,
    ObservedGeneration: foo.Generation,
    Reason:             "DeploymentAvailable",    // CamelCase, machine-readable
    Message:            "Deployment is available", // human-readable
})
```

Rules for conditions:

- `lastTransitionTime` updates **only when `status` changes** (True→False, not on every reconcile)
- `reason` is CamelCase, no spaces, machine-readable — used in tooling
- `message` is human-readable prose
- Unknown means "the controller hasn't determined the state yet" (e.g., waiting for initial sync)

## SharedInformerFactory

```go
factory := informers.NewSharedInformerFactory(client, 30*time.Second)

// Lister + informer for each resource type
deployInformer := factory.Apps().V1().Deployments()
deployLister   := deployInformer.Lister()

podInformer := factory.Core().V1().Pods()
podLister   := podInformer.Lister()

// Register event handlers before starting
deployInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
    AddFunc:    func(obj interface{}) { enqueue(obj) },
    UpdateFunc: func(old, new interface{}) { enqueue(new) },
    DeleteFunc: func(obj interface{}) { enqueueKey(obj) },
})

// Start all informers
factory.Start(stopCh)

// Wait for initial list to complete — ALWAYS do this before starting workers
if !cache.WaitForCacheSync(stopCh,
    deployInformer.Informer().HasSynced,
    podInformer.Informer().HasSynced,
) {
    return errors.New("timed out waiting for caches to sync")
}
```

The 30-second resync period triggers synthetic `UpdateFunc` events for all objects, even if nothing changed. This ensures periodic reconciliation of all objects even if a watch event was lost.

## Work queue internals

```go
queue := workqueue.NewRateLimitingQueue(
    workqueue.NewMaxOfRateLimiter(
        // Token bucket: 10 qps burst of 100
        workqueue.NewItemBucketRateLimiter(10, 100),
        // Per-item exponential backoff: base 5ms, max 1000s
        &workqueue.BucketRateLimiter{Limiter: rate.NewLimiter(rate.Every(5*time.Millisecond), 100)},
    ),
)

// Enqueue a key (not the object — re-GET from cache at reconcile time)
queue.Add(types.NamespacedName{Namespace: ns, Name: name}.String())

// Worker
for {
    key, quit := queue.Get()
    if quit { return }
    if err := reconcile(key.(string)); err != nil {
        queue.AddRateLimited(key)   // exponential backoff
    } else {
        queue.Forget(key)           // reset backoff counter
    }
    queue.Done(key)
}
```

Why enqueue keys, not objects? The object fetched from cache at reconcile time is always current. If you enqueue the object, you might reconcile with stale data. Enqueue the key → always re-GET → always fresh.

## Indexers

The Indexer supports fast lookups beyond namespace/name:

```go
// Register an index on "owner UID" during setup
factory.Core().V1().Pods().Informer().AddIndexers(cache.Indexers{
    "ownerUID": func(obj interface{}) ([]string, error) {
        pod := obj.(*corev1.Pod)
        for _, ref := range pod.OwnerReferences {
            return []string{string(ref.UID)}, nil
        }
        return nil, nil
    },
})

// Query: all pods owned by a specific Foo
pods, err := podLister.Pods(foo.Namespace).List(labels.Everything())

// Or via informer index:
objs, err := podInformer.Informer().GetIndexer().ByIndex("ownerUID", string(foo.UID))
```

controller-runtime registers the `".metadata.controller"` index automatically when you use `Owns()`.
