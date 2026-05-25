# 07 · kubebuilder — Project Scaffold

kubebuilder generates a complete, wired-up project from three commands. It handles
all the boilerplate so you focus on your domain logic.

---

## The three scaffold commands

```bash
# 1. Initialize the module. --domain is your CRD group domain.
kubebuilder init \
  --domain spike.io \
  --repo github.com/zerotohero-dev/spike-operator

# 2. Create an API + controller scaffold.
#    --resource generates types in api/
#    --controller generates the reconciler in internal/controller/
kubebuilder create api \
  --group spike \
  --version v1alpha1 \
  --kind SpikeConfig \
  --resource --controller

# 3. (Optional) Create a webhook scaffold.
kubebuilder create webhook \
  --group spike \
  --version v1alpha1 \
  --kind SpikeConfig \
  --defaulting \
  --programmatic-validation
```

---

## What gets generated

```
project/
├── api/v1alpha1/
│   ├── spikeconfig_types.go        ← YOU EDIT: spec/status structs + markers
│   ├── spikeconfig_webhook.go      ← if webhook was created
│   └── groupversion_info.go        ← GVK registration — do not touch
├── internal/controller/
│   └── spikeconfig_controller.go   ← YOU EDIT: Reconcile() logic
├── config/
│   ├── crd/bases/                  ← GENERATED CRD YAML (make manifests)
│   ├── rbac/                       ← GENERATED RBAC (make manifests)
│   ├── manager/                    ← Manager Deployment YAML
│   └── webhook/                    ← Webhook Service + cert config
├── cmd/main.go                     ← Manager setup — rarely edited
└── Makefile                        ← make generate, make manifests, make deploy
```

The files marked **YOU EDIT** are where your domain logic lives. The generated
files in `config/` are outputs from your Go code — treat them as build artifacts
and never edit them by hand.

---

## The critical make targets

```bash
# Run after changing any +kubebuilder: marker or adding a new type.
# Generates DeepCopy methods required by controller-runtime's runtime.Object.
make generate

# Run after make generate, or after changing RBAC markers.
# Regenerates: config/crd/bases/*.yaml and config/rbac/*.yaml
make manifests

# Build the manager binary
make build

# Run tests (uses envtest — see section 18)
make test

# Install CRDs into your current cluster context
make install

# Build Docker image and push
make docker-build docker-push IMG=your-registry/spike-operator:v0.1.0

# Deploy everything to cluster
make deploy IMG=your-registry/spike-operator:v0.1.0
```

!!! warning "Always run make generate before make manifests"

    `make generate` runs `controller-gen object` which adds `DeepCopyObject()`
    methods to your types. Without these, your types don't satisfy the
    `runtime.Object` interface and nothing compiles.

    `make manifests` then runs `controller-gen crd rbac webhook` to produce YAML
    from your Go markers.

    Forgetting `make generate` causes confusing compile errors. Forgetting
    `make manifests` means your deployed CRD doesn't match your code — which
    causes silent validation failures or missing fields.

---

## CI hygiene

Add this to your CI pipeline to catch uncommitted generated files:

```bash
make generate manifests
git diff --exit-code  # Fail if generated files weren't committed
```

This catches the common mistake of editing markers and forgetting to regenerate.
