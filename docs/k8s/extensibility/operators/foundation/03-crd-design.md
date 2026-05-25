# CRD Design & controller-gen Markers

Your CRD is the API surface. Design it thoughtfully — changing fields later is painful (versioning, conversion webhooks). The struct lives in `api/v1alpha1/webapp_types.go`.

---

## controller-gen Markers

Markers are Go comments starting with `// +`. They're parsed by `controller-gen` to generate CRD YAML, RBAC ClusterRoles, and webhook manifests. They look like magic comments but are the **real API specification** — the generated YAML is output, not source of truth.

```go title="api/v1alpha1/webapp_types.go"
package v1alpha1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    corev1 "k8s.io/api/core/v1"
)

// WebAppSpec defines the desired state of WebApp
type WebAppSpec struct {
    // Image is the container image for the web application.
    // +kubebuilder:validation:MinLength=1
    Image string `json:"image"`

    // Replicas is the desired replica count.
    // +kubebuilder:validation:Minimum=0
    // +kubebuilder:validation:Maximum=100
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`

    // Port is the port the container listens on.
    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=65535
    // +kubebuilder:default=8080
    Port int32 `json:"port,omitempty"`

    // Ingress configures optional external access.
    // +optional
    Ingress *IngressSpec `json:"ingress,omitempty"`

    // Resources allows setting CPU/memory requests and limits.
    // +optional
    Resources corev1.ResourceRequirements `json:"resources,omitempty"`

    // Env injects extra environment variables.
    // +optional
    Env []corev1.EnvVar `json:"env,omitempty"`
}

type IngressSpec struct {
    // Host is the DNS hostname for the ingress rule.
    // +kubebuilder:validation:Pattern=`^[a-z0-9][a-z0-9\-\.]*[a-z0-9]$`
    Host string `json:"host"`

    // TLS enables TLS via cert-manager annotation.
    // +optional
    TLS bool `json:"tls,omitempty"`

    // IngressClassName selects the ingress controller.
    // +optional
    IngressClassName *string `json:"ingressClassName,omitempty"`
}

// WebAppStatus defines the observed state of WebApp
type WebAppStatus struct {
    // Conditions represent the latest available observations.
    // +optional
    // +listType=map
    // +listMapKey=type
    Conditions []metav1.Condition `json:"conditions,omitempty"`

    // ReadyReplicas is the count of ready pods.
    // +optional
    ReadyReplicas int32 `json:"readyReplicas,omitempty"`

    // ObservedGeneration tracks which spec version we last reconciled.
    // +optional
    ObservedGeneration int64 `json:"observedGeneration,omitempty"`

    // URL is the externally accessible URL (if ingress configured).
    // +optional
    URL string `json:"url,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Replicas",type=integer,JSONPath=`.spec.replicas`
// +kubebuilder:printcolumn:name="Ready",type=integer,JSONPath=`.status.readyReplicas`
// +kubebuilder:printcolumn:name="URL",type=string,JSONPath=`.status.url`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type WebApp struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   WebAppSpec   `json:"spec,omitempty"`
    Status WebAppStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true
type WebAppList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []WebApp `json:"items"`
}
```

---

## Marker Reference

| Marker | Effect | Notes |
|--------|--------|-------|
| `+kubebuilder:object:root=true` | Marks as a root CRD object | Required on every root type |
| `+kubebuilder:subresource:status` | Enables `/status` subresource | Status updates require `r.Status().Update()` — see [§05](../reconciliation/05-status-conditions.md) |
| `+kubebuilder:validation:MinLength=N` | CRD validation (OpenAPI v3) | Enforced by API server before reconcile is called |
| `+kubebuilder:validation:Minimum=N` | Numeric minimum | Same |
| `+kubebuilder:validation:Pattern=...` | Regex validation | Must be a Go raw string literal |
| `+kubebuilder:default=value` | Server-side default | Applied when field is omitted |
| `+kubebuilder:printcolumn:...` | `kubectl get` columns | JSONPath into spec or status |
| `+listType=map` + `+listMapKey=type` | Strategic merge for lists | Required for conditions arrays |
| `+optional` | Field can be omitted | Match with `omitempty` in json tag |

---

## Status Subresource — Critical Detail

!!! danger "Status writes require r.Status().Update()"
    When `+kubebuilder:subresource:status` is enabled, updating `.status` requires calling `r.Status().Update()`, **not** `r.Update()`. If you call `r.Update()` with a modified status, the status changes will be **silently dropped**. The API server accepts the request but ignores the status fields.

    The status subresource also means users cannot accidentally overwrite status with `kubectl apply` — only the controller can write it.

```go
// WRONG — status changes are dropped silently
webapp.Status.ReadyReplicas = 3
r.Update(ctx, webapp) // ← spec is saved, status is NOT

// CORRECT
webapp.Status.ReadyReplicas = 3
r.Status().Update(ctx, webapp) // ← goes to /status subresource
```

---

## Generation vs ResourceVersion

!!! info "Use Generation, not ResourceVersion"
    - **`metadata.generation`** is incremented only when `.spec` changes
    - **`metadata.resourceVersion`** changes on every write, including status updates

    Always use `Generation` to track "did spec change since last reconcile". Using `ResourceVersion` for this would cause reconcile on every status update, creating a storm.

---

## CEL Validation for Immutable Fields

Use `+kubebuilder:validation:XValidation` (Common Expression Language) to enforce immutability:

```go
// This field cannot be changed after creation
// +kubebuilder:validation:XValidation:rule="self == oldSelf",message="dbName is immutable after creation"
DBName string `json:"dbName"`
```

CEL rules have access to `self` (new value) and `oldSelf` (previous value) for update validations. They're evaluated by the API server, so violations are rejected before reconcile is ever called.

---

## Spec Design Principles

!!! tip "Design spec fields thoughtfully"
    - Prefer **optional fields with defaults** over required fields where sensible
    - Make fields **immutable when change requires complex migration** (use CEL)
    - Use **pointer types** for optional structs (`*IngressSpec`) — nil means "not set"
    - Use **embedded structs** to group related fields (`IngressSpec`, `TLSSpec`)
    - **Never** put operational state in spec (e.g., `spec.lastRestartedAt`) — that belongs in status

```go
// Good: optional nested config
// +optional
Ingress *IngressSpec `json:"ingress,omitempty"`

// Good: pointer for optional primitive with semantic nil (vs zero value)
// +optional
Replicas *int32 `json:"replicas,omitempty"` // nil = "use default", 0 = "scale to zero"

// Bad: mixing desired state with operational metadata
LastDeployedImage string `json:"lastDeployedImage"` // belongs in status
```
