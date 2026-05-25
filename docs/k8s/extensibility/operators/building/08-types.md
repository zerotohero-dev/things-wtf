# 08 · Writing Your Types

The types file is where you define your API. It drives everything: the CRD schema,
the RBAC rules, printer columns, validation, and defaults — all via Go struct tags
and **kubebuilder markers** (comments starting with `// +kubebuilder:`).

---

## Full annotated types file

```go
package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// ── Spec ──────────────────────────────────────────────────────────────────────

// SpikeConfigSpec defines the DESIRED state. Users write this.
type SpikeConfigSpec struct {
    // WorkloadId is the SPIFFE ID this config applies to.
    // +kubebuilder:validation:Required
    // +kubebuilder:validation:Pattern=`^spiffe://`
    WorkloadId string `json:"workloadId"`

    // TTL is the desired SVID lifetime in seconds.
    // +kubebuilder:default=86400
    // +kubebuilder:validation:Minimum=3600
    // +kubebuilder:validation:Maximum=604800
    // +optional
    TTL int64 `json:"ttl,omitempty"`

    // SVIDType controls whether to issue X.509 or JWT SVIDs.
    // +kubebuilder:default=x509
    // +kubebuilder:validation:Enum=x509;jwt
    // +optional
    SVIDType string `json:"svidType,omitempty"`
}

// ── Status ────────────────────────────────────────────────────────────────────

// SpikeConfigStatus defines the OBSERVED state. The controller writes this.
type SpikeConfigStatus struct {
    // Phase is a high-level summary of the object's state.
    // +kubebuilder:validation:Enum=Pending;Provisioning;Ready;Failed
    // +optional
    Phase string `json:"phase,omitempty"`

    // Conditions are the standard Kubernetes condition list.
    // Using metav1.Condition is the established convention.
    // +optional
    // +patchMergeKey=type
    // +patchStrategy=merge
    // +listType=map
    // +listMapKey=type
    Conditions []metav1.Condition `json:"conditions,omitempty"`

    // ObservedGeneration is the .metadata.generation the controller last
    // reconciled. Lets you detect whether status reflects the current spec.
    // +optional
    ObservedGeneration int64 `json:"observedGeneration,omitempty"`

    // ExpiresAt is when the current SVID expires.
    // +optional
    ExpiresAt *metav1.Time `json:"expiresAt,omitempty"`
}

// ── Root Type ─────────────────────────────────────────────────────────────────

// +kubebuilder:object:root=true           ← required: enables code generation
// +kubebuilder:subresource:status         ← creates /status subresource
// +kubebuilder:resource:scope=Namespaced,shortName=sc
// +kubebuilder:printcolumn:name="WorkloadID",type=string,JSONPath=`.spec.workloadId`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Expires",type=date,JSONPath=`.status.expiresAt`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

type SpikeConfig struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    Spec   SpikeConfigSpec   `json:"spec,omitempty"`
    Status SpikeConfigStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true
type SpikeConfigList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items []SpikeConfig `json:"items"`
}
```

---

## Markers reference

| Marker | What it generates | Applied to |
|---|---|---|
| `+kubebuilder:object:root=true` | Registers type as a root API object | struct |
| `+kubebuilder:subresource:status` | `subresources: status: {}` in CRD | struct |
| `+kubebuilder:validation:Required` | Field required in OpenAPI schema | field |
| `+kubebuilder:validation:Pattern=\`...\`` | Regex validation in OpenAPI schema | field |
| `+kubebuilder:default=value` | Default value injected at admission | field |
| `+kubebuilder:validation:Enum=a;b` | Enum constraint in OpenAPI schema | field |
| `+kubebuilder:validation:Minimum=N` | Numeric minimum | field |
| `+kubebuilder:printcolumn:...` | `additionalPrinterColumns` in CRD | struct |
| `+kubebuilder:rbac:...` | ClusterRole YAML in config/rbac/ | controller func |
| `+optional` | Marks field as optional in the schema | field |

!!! info "Why defaults in the schema?"

    Schema defaults (`+kubebuilder:default=86400`) are injected by the API server's
    admission pipeline *before* the object is stored. This means the field is
    populated even if the user didn't specify it, and your controller can always rely
    on it having a value. This is different from defaulting in a webhook (which is
    more flexible but requires a running webhook pod).

---

## The json tags matter

Every field needs proper JSON tags:

- `json:"fieldName"` — required field
- `json:"fieldName,omitempty"` — optional field (omit from JSON if zero value)

Without `omitempty` on optional fields, your spec will serialize empty strings and
zero integers into every object, making diffs noisy and accidentally triggering
validation on fields users didn't set.
