# Toolchain Setup

We use **kubebuilder v4** for scaffolding, **controller-gen** (bundled) for generating CRD manifests and RBAC, and **kind** for a local cluster. No Operator SDK — we want to understand every layer.

---

## Create the kind Cluster

```yaml title="kind-config.yaml"
# Exposes controller-manager and etcd metrics — useful during development
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        controllerManager:
          extraArgs:
            bind-address: 0.0.0.0
        etcd:
          local:
            extraArgs:
              listen-metrics-urls: http://0.0.0.0:2381
  - role: worker
```

```bash
# Create cluster
kind create cluster --name operator-lab --config kind-config.yaml

# Verify
kubectl cluster-info --context kind-operator-lab
```

---

## Install kubebuilder

```bash
# macOS / Linux
curl -L -o kubebuilder \
  https://github.com/kubernetes-sigs/kubebuilder/releases/latest/download/kubebuilder_$(go env GOOS)_$(go env GOARCH)
chmod +x kubebuilder && sudo mv kubebuilder /usr/local/bin/

kubebuilder version
```

---

## Scaffold the Project

```bash
# Create project directory
mkdir webapp-operator && cd webapp-operator

# Initialize — sets module path and domain for API group
kubebuilder init \
  --domain example.com \
  --repo github.com/yourorg/webapp-operator

# Create the API: CRD struct + Controller scaffold
kubebuilder create api \
  --group apps \
  --version v1alpha1 \
  --kind WebApp \
  --resource \    # create the types file
  --controller    # create the controller file
```

### The Make Targets You'll Use Every Day

| Command | What it does |
|---------|-------------|
| `make manifests` | Runs `controller-gen` to generate CRD YAML, RBAC, and webhook configs from markers |
| `make generate` | Runs `controller-gen` to generate `DeepCopy` methods |
| `make install` | Applies generated CRDs to the current cluster |
| `make run` | Runs the controller locally, connected to the kind cluster |
| `make build` | Compiles the manager binary |
| `make docker-build` | Builds the container image |
| `make envtest` | Downloads API server/etcd binaries for integration tests |

!!! warning "Run order matters"
    Always run `make generate` before `make manifests`, and `make manifests` before `make install`. If your CRD YAML is stale, `make install` will apply old schemas.

---

## Understanding the Project Structure

```text
webapp-operator/
├── api/v1alpha1/
│   ├── webapp_types.go          # Your CRD struct — edit this
│   ├── zz_generated.deepcopy.go # Auto-generated, NEVER edit
│   └── groupversion_info.go     # Scheme registration
├── internal/controller/
│   └── webapp_controller.go     # Your reconciler — main logic lives here
├── config/
│   ├── crd/bases/               # Generated CRD YAML (from make manifests)
│   ├── rbac/                    # Generated ClusterRole from +kubebuilder:rbac markers
│   ├── manager/                 # Deployment, ServiceAccount for the operator pod
│   └── default/                 # Kustomize overlays
├── cmd/
│   └── main.go                  # Manager setup — leader election, metrics, cache options
├── Makefile                     # All build targets
└── go.mod
```

!!! danger "Never edit zz_generated files"
    Files prefixed with `zz_generated.` are fully managed by `make generate`. Your edits will be overwritten on the next run. The same applies to `config/crd/bases/` — those are *output*, not source of truth. Your source of truth is the **markers in your Go types**.

---

## The Generated main.go

Understanding what the scaffold generates in `cmd/main.go` is important before you start customizing it:

```go title="cmd/main.go (annotated)"
func main() {
    // 1. Parse flags (metrics addr, leader election, etc.)
    // 2. Create the Manager — this is the central object that:
    //    - Manages the cache (informers)
    //    - Manages the work queues
    //    - Runs leader election
    //    - Serves metrics and health endpoints
    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme:                 scheme,
        Metrics:                metricsserver.Options{BindAddress: metricsAddr},
        HealthProbeBindAddress: probeAddr,
        LeaderElection:         enableLeaderElection,
        LeaderElectionID:       "webapp-operator.example.com",
    })

    // 3. Register your controller with the manager
    if err = (&controller.WebAppReconciler{
        Client: mgr.GetClient(),
        Scheme: mgr.GetScheme(),
    }).SetupWithManager(mgr); err != nil {
        setupLog.Error(err, "unable to create controller")
        os.Exit(1)
    }

    // 4. Start everything — blocks until context is cancelled
    // The manager will:
    //   - Start informers and wait for cache sync
    //   - Acquire leader election lease (if enabled)
    //   - Then start your reconciler workers
    if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
        setupLog.Error(err, "problem running manager")
        os.Exit(1)
    }
}
```

!!! info "Cache sync on startup"
    The manager will not call your `Reconcile` function until all informers have synced (completed the initial `List`). This means every object matching your watches is reconciled on every operator restart. **This is by design — and your reconciler must be idempotent because of it.**
