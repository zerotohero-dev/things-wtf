# Operators

An operator is a controller that encodes **operational knowledge**: installation, upgrade, backup, scaling, failover. The term "operator pattern" simply means a controller whose primary resource is a domain-specific CRD, and whose reconcile logic implements what a human operator would do.

## controller-runtime

The library underpinning kubebuilder and operator-sdk. Key abstractions:

### Manager

Bootstraps all shared dependencies. One Manager per operator binary.

```go
mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
    Scheme:                 scheme,
    Metrics:                metricsserver.Options{BindAddress: ":8080"},
    HealthProbeBindAddress: ":8081",
    LeaderElection:         true,
    LeaderElectionID:       "my-operator.example.io",
    LeaseDuration:          pointer.Duration(15 * time.Second),
    RenewDeadline:          pointer.Duration(10 * time.Second),
    RetryPeriod:            pointer.Duration(2 * time.Second),
    // Cache options: restrict to specific namespaces, or label selectors
    Cache: cache.Options{
        DefaultNamespaces: map[string]cache.Config{
            "my-operator-namespace": {},
            "target-namespace": {},
        },
    },
})
```

The Manager provides:

- `client.Client` — reads from cache, writes to API server
- `cache.Cache` — shared informer factory
- `runtime.Scheme` — GVK ↔ Go type registry
- Health/readiness endpoints
- Leader election via Lease
- Prometheus metrics server
- Signal handling (SIGTERM → graceful shutdown)

### Controller

Wires a Reconciler to watched resources:

```go
err = ctrl.NewControllerManagedBy(mgr).
    For(&examplev1.Foo{}).                    // primary resource — reconcile on any change
    Owns(&appsv1.Deployment{}).               // owned resource — reconcile owner on change
    Owns(&corev1.Service{}).
    Watches(                                  // arbitrary watch with custom handler
        &corev1.ConfigMap{},
        handler.EnqueueRequestsFromMapFunc(func(ctx context.Context, obj client.Object) []reconcile.Request {
            // map ConfigMap → list of Foos that reference it
            return r.foosReferencingConfigMap(ctx, obj)
        }),
        builder.WithPredicates(predicate.ResourceVersionChangedPredicate{}),
    ).
    WithOptions(controller.Options{MaxConcurrentReconciles: 5}).
    Complete(&FooReconciler{Client: mgr.GetClient(), Scheme: mgr.GetScheme()})
```

### Predicates

Filter which events trigger reconciliation (reduces unnecessary reconcile calls):

```go
builder.WithPredicates(
    predicate.Or(
        predicate.GenerationChangedPredicate{},    // spec change
        predicate.AnnotationChangedPredicate{},    // annotation change
        predicate.LabelChangedPredicate{},
    ),
)

// Custom predicate
type MyPredicate struct{ predicate.Funcs }
func (MyPredicate) Update(e event.UpdateEvent) bool {
    old := e.ObjectOld.(*examplev1.Foo)
    new := e.ObjectNew.(*examplev1.Foo)
    return old.Spec.Replicas != new.Spec.Replicas
}
```

## kubebuilder

Code generation tool that scaffolds CRDs, controllers, webhooks, and tests from Go struct tags and comments.

### Marker annotations

```go
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:subresource:scale:specpath=.spec.replicas,statuspath=.status.replicas
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
// +kubebuilder:resource:scope=Namespaced,shortName=fo,categories=all
// +kubebuilder:storageversion

// +kubebuilder:rbac:groups=example.io,resources=foos,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=example.io,resources=foos/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=example.io,resources=foos/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
type Foo struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    Spec   FooSpec   `json:"spec,omitempty"`
    Status FooStatus `json:"status,omitempty"`
}

// +kubebuilder:validation:Required
// +kubebuilder:validation:Minimum=1
// +kubebuilder:validation:Maximum=100
Replicas int32 `json:"replicas"`

// +kubebuilder:validation:Pattern=`^[a-z0-9/.:@-]+$`
Image string `json:"image"`
```

Generate CRD manifests + RBAC:

```bash
make generate    # runs controller-gen to regenerate deepcopy methods
make manifests   # generates CRD YAML from markers
```

## Leader election

Operators run N replicas for HA. Only one should actively reconcile.

controller-runtime uses a Kubernetes `Lease` object (in `coordination.k8s.io/v1`):

```
Lease: my-operator.example.io in namespace kube-system
  holderIdentity: pod-abc123
  leaseDurationSeconds: 15
  acquireTime: 2024-01-15T10:00:00Z
  renewTime: 2024-01-15T10:00:10Z
```

- The leader renews the lease every `RenewDeadline`
- Non-leaders watch the lease; if it's not renewed within `LeaseDuration`, they attempt to acquire it
- On acquisition: the new leader's Manager starts, controllers begin reconciling

!!! note "Leader election is per-Manager"
    Multiple controllers in one binary share leadership — they all start/stop together. For independent leadership, use separate operator binaries.

## Webhooks

controller-runtime integrates defaulting and validating webhooks. Implement on the CRD type:

```go
// Defaulting
func (f *Foo) Default() {
    if f.Spec.Replicas == 0 {
        f.Spec.Replicas = 1
    }
    if f.Spec.Timeout == 0 {
        f.Spec.Timeout = metav1.Duration{Duration: 30 * time.Second}
    }
}

// Validation
func (f *Foo) ValidateCreate() (admission.Warnings, error) {
    return nil, f.validateFoo()
}

func (f *Foo) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
    oldFoo := old.(*Foo)
    if f.Spec.Image != oldFoo.Spec.Image && f.Spec.Replicas > 0 {
        return nil, field.Invalid(
            field.NewPath("spec", "image"),
            f.Spec.Image,
            "cannot change image while running",
        )
    }
    return nil, f.validateFoo()
}

func (f *Foo) ValidateDelete() (admission.Warnings, error) {
    return nil, nil
}
```

Register with the manager:

```go
if err = (&examplev1.Foo{}).SetupWebhookWithManager(mgr); err != nil {
    return err
}
```

kubebuilder generates `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration` manifests from `// +kubebuilder:webhook:...` markers. TLS is managed by cert-manager or the kubebuilder webhook certificate rotator.

## Operator maturity model

| Level | Capabilities |
|---|---|
| 1 — Basic Install | Automated install and configuration |
| 2 — Seamless Upgrades | Patch and minor version upgrades |
| 3 — Full Lifecycle | Backup, recovery, failure handling |
| 4 — Deep Insights | Metrics, alerts, log processing, workload analysis |
| 5 — Auto Pilot | Horizontal/vertical scaling, auto-config tuning, anomaly detection |

Most production operators live at levels 2–3. Level 5 requires deep domain knowledge and is rare.

## Health probes

```go
mgr.AddHealthzCheck("healthz", healthz.Ping)
mgr.AddReadyzCheck("readyz", healthz.Ping)

// Custom check — e.g., verify cache is synced
mgr.AddReadyzCheck("cache-sync", func(req *http.Request) error {
    if !mgr.GetCache().WaitForCacheSync(req.Context()) {
        return errors.New("cache not synced")
    }
    return nil
})
```

## Metrics

controller-runtime exposes default metrics on `:8080/metrics`:

- `controller_runtime_reconcile_total{controller, result}` — reconcile count by outcome
- `controller_runtime_reconcile_errors_total{controller}` — error count
- `controller_runtime_reconcile_time_seconds{controller}` — reconcile duration histogram
- `workqueue_depth{name}` — work queue depth
- `workqueue_queue_duration_seconds{name}` — time items wait in queue

Add custom metrics:

```go
var (
    foosManaged = prometheus.NewGaugeVec(prometheus.GaugeOpts{
        Name: "myoperator_foos_managed_total",
        Help: "Number of Foo objects managed",
    }, []string{"namespace", "phase"})
)

func init() {
    metrics.Registry.MustRegister(foosManaged)
}
```
