# Admission Control

Admission plugins run in the API server after AuthN and AuthZ, in the path of every write request. Two phases run in order: **mutating** (can modify the object) → **validating** (can only accept or reject).

## The admission chain

```
AuthN → AuthZ → Mutating plugins → Object validation → Validating plugins → etcd
```

Mutating plugins run sequentially (order matters — later plugins see changes from earlier ones). Validating plugins run in parallel (all failures are aggregated).

Built-in plugins (enabled by default): `NamespaceLifecycle`, `LimitRanger`, `ServiceAccount`, `ResourceQuota`, `DefaultStorageClass`, `DefaultTolerationSeconds`, `MutatingAdmissionWebhook`, `ValidatingAdmissionWebhook`, `ValidatingAdmissionPolicy`.

## MutatingAdmissionWebhook

The webhook receives an `AdmissionReview`, returns an `AdmissionResponse` with JSON Patch operations:

```json
{
  "response": {
    "uid": "<from request>",
    "allowed": true,
    "patchType": "JSONPatch",
    "patch": "W3sib3AiOiJhZGQiLCJwYXRoIjoiL21ldGFkYXRhL2xhYmVscyIsInZhbHVlIjp7ImluamVjdGVkIjoidHJ1ZSJ9fV0="
  }
}
```

(patch is base64 JSON Patch)

In controller-runtime:

```go
type PodMutator struct{}

func (m *PodMutator) Handle(ctx context.Context, req admission.Request) admission.Response {
    pod := &corev1.Pod{}
    if err := json.Unmarshal(req.Object.Raw, pod); err != nil {
        return admission.Errored(http.StatusBadRequest, err)
    }

    // Add a sidecar container
    pod.Spec.Containers = append(pod.Spec.Containers, corev1.Container{
        Name:  "my-sidecar",
        Image: "my-sidecar:latest",
    })

    marshaledPod, err := json.Marshal(pod)
    if err != nil {
        return admission.Errored(http.StatusInternalServerError, err)
    }
    return admission.PatchResponseFromRaw(req.Object.Raw, marshaledPod)
}
```

### Reinvocation

If a mutating webhook modifies an object, other webhooks may not have seen the changes. Webhooks with `reinvocationPolicy: IfNeeded` are re-called if any webhook mutates the object:

```yaml
webhooks:
- name: my-injector.example.io
  reinvocationPolicy: IfNeeded   # re-run if another webhook mutated the object
```

Default is `Never`. Use `IfNeeded` for order-sensitive mutations (e.g., a sidecar injector that depends on labels set by another webhook).

## ValidatingAdmissionWebhook

Same protocol, but the response only contains `allowed: true/false` (no patch). All validating webhooks run in parallel; any rejection causes the request to fail with the combined error messages.

```go
func (v *DeploymentValidator) Handle(ctx context.Context, req admission.Request) admission.Response {
    deploy := &appsv1.Deployment{}
    if err := json.Unmarshal(req.Object.Raw, deploy); err != nil {
        return admission.Errored(http.StatusBadRequest, err)
    }

    if _, ok := deploy.Labels["app.kubernetes.io/name"]; !ok {
        return admission.Denied("deployment must have app.kubernetes.io/name label")
    }

    return admission.Allowed("")
}
```

## WebhookConfiguration

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
webhooks:
- name: validate-deployments.example.io
  admissionReviewVersions: [v1]
  clientConfig:
    service:
      name: my-operator-webhook
      namespace: my-operator-system
      port: 443
      path: /validate-apps-v1-deployment
    caBundle: <base64-encoded CA cert>
  rules:
  - apiGroups:   ["apps"]
    apiVersions: ["v1"]
    operations:  ["CREATE", "UPDATE"]
    resources:   ["deployments"]
    scope:       Namespaced
  matchPolicy: Equivalent         # also match converted API versions
  namespaceSelector:
    matchExpressions:
    - key: admission.example.io/skip
      operator: DoesNotExist
    - key: kubernetes.io/metadata.name
      operator: NotIn
      values: [kube-system, my-operator-system]
  objectSelector:
    matchLabels:
      admission.example.io/validate: "true"
  failurePolicy: Fail             # Fail | Ignore
  timeoutSeconds: 10
  sideEffects: None               # None | NoneOnDryRun
```

### Critical configuration choices

**`failurePolicy: Fail` vs `Ignore`**

`Fail` — if the webhook is unreachable or returns an error, the request is rejected. Safer for security-critical webhooks (e.g., image policy). But an outage of your webhook service blocks all matching requests in the cluster.

`Ignore` — if the webhook fails, the request proceeds anyway. Use for advisory webhooks (warnings, metrics).

**`sideEffects`**

Set to `None` for webhooks that don't modify external state. Required to participate in dry-run requests (`kubectl apply --dry-run=server`). If your webhook has side effects (e.g., creates an external resource), use `NoneOnDryRun` and check `req.DryRun` in your handler.

**`namespaceSelector`** — Always exclude your own operator namespace and `kube-system`. Otherwise, a broken webhook can prevent its own pods from starting.

**`matchPolicy: Equivalent`** — Match requests for the resource regardless of which API version was used. Without this, a webhook registered for `apps/v1` Deployments won't fire for `extensions/v1beta1` Deployment requests (which are then converted).

## ValidatingAdmissionPolicy

*GA since 1.30.* CEL expressions run in-process — no webhook server, no network call, no availability dependency.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-app-labels
spec:
  failurePolicy: Fail
  paramKind:                          # optional: reference a config object
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
    - apiGroups:   ["apps"]
      apiVersions: ["v1"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["deployments"]
  variables:
  - name: labels
    expression: "object.metadata.labels"
  validations:
  - expression: "'app.kubernetes.io/name' in variables.labels"
    message: "deployment must have app.kubernetes.io/name label"
    reason: Required
  - expression: "'app.kubernetes.io/version' in variables.labels"
    messageExpression: "'missing version label on deployment ' + object.metadata.name"
  auditAnnotations:                   # add to audit log without rejecting
  - key: missing-owner
    valueExpression: >
      !('owner' in variables.labels) ? 'missing owner label' : ''
```

Bind to a namespace or set of resources:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-app-labels-binding
spec:
  policyName: require-app-labels
  validationActions: [Deny]           # Deny | Warn | Audit
  matchResources:
    namespaceSelector:
      matchLabels: {environment: production}
  paramRef:                           # optional: pass a ConfigMap as params
    name: my-policy-config
    namespace: default
    parameterNotFoundAction: Deny
```

`validationActions`:

- `Deny` — reject the request if validation fails
- `Warn` — allow but add a warning header
- `Audit` — allow but record in audit log

Multiple actions can be combined: `[Deny, Audit]`.

### VAP vs webhook: when to use each

| Scenario | Use |
|---|---|
| Simple field validation | VAP (CEL) |
| Cross-object validation (check another resource) | Webhook |
| Mutations (defaulting, injection) | Mutating webhook |
| Complex business logic | Webhook |
| No operational overhead desired | VAP |
| Response time critical path | VAP (no network hop) |
