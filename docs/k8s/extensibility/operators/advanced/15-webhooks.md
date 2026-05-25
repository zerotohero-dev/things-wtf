# 15 · Webhooks

Admission webhooks are HTTP callbacks the API server invokes during the object
admission pipeline — before the object is stored in etcd. They let you implement
defaulting, complex validation, and version conversion that schema markers alone
cannot handle.

---

## The three webhook types

| Type | When it runs | Can it modify? | Use for |
|---|---|---|---|
| **Mutating** | First, before validation | Yes | Defaults, normalization, injecting fields |
| **Validating** | After mutating, before storage | No (approve/reject only) | Cross-field validation, external state checks |
| **Conversion** | When version translation is needed | Yes | CRD multi-version support |

The admission pipeline order:

```
kubectl apply
    │
    ▼
API server (auth + schema validation)
    │
    ▼
Mutating webhooks   ← can modify the object
    │
    ▼
Object validation against schema
    │
    ▼
Validating webhooks ← approve or reject only
    │
    ▼
etcd write
```

---

## Scaffold and implementation

```bash
kubebuilder create webhook \
  --group spike \
  --version v1alpha1 \
  --kind SpikeConfig \
  --defaulting \
  --programmatic-validation
```

```go
// api/v1alpha1/spikeconfig_webhook.go

// Mutating webhook: set defaults that can't be expressed in schema markers.
// Runs before validation. Can modify the object freely.
func (r *SpikeConfig) Default() {
    if r.Spec.TTL == 0 {
        r.Spec.TTL = 86400
    }
    if r.Spec.SVIDType == "" {
        r.Spec.SVIDType = "x509"
    }
}

// ValidateCreate: runs when the object is first created.
func (r *SpikeConfig) ValidateCreate() (admission.Warnings, error) {
    return r.validate()
}

// ValidateUpdate: runs when the object is updated.
func (r *SpikeConfig) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
    oldSC, ok := old.(*SpikeConfig)
    if !ok {
        return nil, fmt.Errorf("expected SpikeConfig")
    }

    // Immutability: workloadId cannot change after creation.
    // Schema markers cannot express "immutable after create" — webhooks can.
    if r.Spec.WorkloadId != oldSC.Spec.WorkloadId {
        return nil, field.Forbidden(
            field.NewPath("spec", "workloadId"),
            "workloadId is immutable",
        )
    }
    return r.validate()
}

func (r *SpikeConfig) ValidateDelete() (admission.Warnings, error) {
    return nil, nil
}

func (r *SpikeConfig) validate() (admission.Warnings, error) {
    // Cross-field validation: JWT SVIDs require shorter TTLs.
    // This cannot be expressed in schema markers — it depends on another field.
    if r.Spec.SVIDType == "jwt" && r.Spec.TTL > 3600 {
        return nil, field.Invalid(
            field.NewPath("spec", "ttl"),
            r.Spec.TTL,
            "JWT SVIDs must have TTL ≤ 3600 seconds",
        )
    }
    return nil, nil
}
```

---

## TLS and cert-manager

Webhooks must be served over HTTPS. The API server needs a CA bundle to verify the
webhook server's TLS certificate. The kubebuilder scaffold in `config/certmanager/`
generates cert-manager `Certificate` and `Issuer` resources to handle this
automatically.

Without cert-manager, you need to manually generate a self-signed CA, create a
Secret with the cert, and patch the webhook configuration's `caBundle` field. This
is operationally painful. **Use cert-manager.**

---

## failurePolicy: the platform availability trap

!!! danger "failurePolicy: Fail can take down your platform"

    When a webhook has `failurePolicy: Fail` (the default), if the webhook pod is
    down or unreachable, **all creates and updates for that resource type fail
    cluster-wide**. This means: if your operator's webhook is broken, no new
    `SpikeConfig` objects can be created, and no existing ones can be updated.

    Mitigation options:

    - Run the webhook with **2+ replicas** (cert-manager does this)
    - Set `failurePolicy: Ignore` with compensating validation in the controller
    - Set a short `timeoutSeconds` (default 10s) to fail fast rather than blocking
    - Emergency fix: patch `failurePolicy` to `Ignore` while fixing the webhook

    ```bash
    # Emergency: switch to Ignore while fixing the webhook pod
    kubectl patch validatingwebhookconfiguration spike-validating-webhook \
      --type=json \
      -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
    ```

---

## Conversion webhooks

??? example "Deep dive: conversion webhooks for multi-version CRDs"

    When your CRD serves multiple versions (e.g., `v1alpha1` and `v1`), the API
    server uses a conversion webhook to translate between them on reads and writes.

    The standard pattern is **Hub and Spoke**:

    - One version is the Hub (usually the latest stable: `v1`)
    - All other versions are Spokes (`v1alpha1`, `v1beta1`)
    - Every Spoke implements `ConvertTo(hub)` and `ConvertFrom(hub)`

    ```go
    // v1alpha1 Spoke → v1 Hub
    func (src *SpikeConfig) ConvertTo(dstRaw conversion.Hub) error {
        dst := dstRaw.(*v1.SpikeConfig)
        dst.Spec.WorkloadID = src.Spec.WorkloadId  // field rename example
        dst.Spec.TTL = src.Spec.TTL
        return nil
    }

    // v1 Hub → v1alpha1 Spoke
    func (dst *SpikeConfig) ConvertFrom(srcRaw conversion.Hub) error {
        src := srcRaw.(*v1.SpikeConfig)
        dst.Spec.WorkloadId = src.Spec.WorkloadID
        dst.Spec.TTL = src.Spec.TTL
        return nil
    }
    ```

    Conversion must be **lossless and round-trippable**: converting to the hub and
    back must produce the original object. Any data in a Spoke that has no
    equivalent in the Hub will be lost on round-trip — avoid this.

    Register the conversion webhook in `cmd/main.go` and configure
    `config/certmanager/` for its TLS certificate, just like admission webhooks.
