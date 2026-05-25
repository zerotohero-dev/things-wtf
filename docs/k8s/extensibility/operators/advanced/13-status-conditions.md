# 13 · Status Conditions

The Kubernetes community converged on `metav1.Condition` as the standard for
communicating controller state. Use it. Don't invent custom status fields when
conditions cover the case.

---

## The Condition type

```go
type Condition struct {
    Type               string          // e.g. "Ready", "Synced", "Degraded"
    Status             ConditionStatus // "True", "False", "Unknown"
    ObservedGeneration int64           // generation when this was written
    LastTransitionTime Time            // set automatically by SetStatusCondition
    Reason             string          // CamelCase machine-readable, e.g. "SVIDExpired"
    Message            string          // human-readable detail
}
```

---

## Setting conditions correctly

```go
import "k8s.io/apimachinery/pkg/api/meta"

// SetStatusCondition handles:
// - Creating the condition if it doesn't exist
// - Updating it if it changed
// - Setting LastTransitionTime ONLY when Status actually changes
meta.SetStatusCondition(&sc.Status.Conditions, metav1.Condition{
    Type:               "Ready",
    Status:             metav1.ConditionTrue,
    Reason:             "SVIDProvisioned",
    Message:            "X.509 SVID issued successfully",
    ObservedGeneration: sc.Generation,   // always set this
})

// Reading conditions:
cond := meta.FindStatusCondition(sc.Status.Conditions, "Ready")
if cond != nil && cond.Status == metav1.ConditionTrue {
    // object is ready
}
```

---

## ObservedGeneration — the most overlooked field

`metadata.generation` is incremented by the API server every time a user changes
the spec. `status.observedGeneration` is what your controller sets to record which
generation of the spec it has processed.

Without it, you cannot tell whether `Ready: True` reflects *the current spec* or
a spec from three versions ago.

Tools like Flux, ArgoCD, and `kubectl wait` use `observedGeneration` to decide
whether reconciliation is complete. Always set it:

```go
sc.Status.ObservedGeneration = sc.Generation
```

---

## Checking status from the command line

```bash
# Wait until the controller has processed the current spec
kubectl wait spikeconfig/my-config \
  --for=condition=Ready \
  --timeout=120s

# Detect spec/status drift (generation != observedGeneration)
kubectl get spikeconfig my-config -o json | jq '{
  generation: .metadata.generation,
  observedGeneration: .status.observedGeneration,
  ready: (.status.conditions[] | select(.type=="Ready") | .status)
}'

# Find all objects where controller hasn't processed the latest spec (cluster-wide)
kubectl get spikeconfig -A -o json | \
  jq '.items[] | select(.metadata.generation != .status.observedGeneration) |
      {name: .metadata.name, ns: .metadata.namespace}'
```

---

## Condition naming conventions

| Convention | Example | Notes |
|---|---|---|
| `Type` | `Ready`, `Synced`, `Degraded` | Stable, CamelCase, describes a binary state |
| `Reason` | `SVIDProvisioned`, `ProvisioningFailed` | CamelCase, machine-readable, no spaces |
| `Message` | `"SVID issued, expires 2026-04-01"` | Human-readable, may change freely |
| `Status` | `True`, `False`, `Unknown` | Use `Unknown` while an operation is in progress |
