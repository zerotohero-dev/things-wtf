# Custom Resource Definitions

CRDs extend the Kubernetes API with new types. The API server serves CRDs through the same machinery as built-in types — watch, list, RBAC, admission, SSA, status subresource, scale subresource — all work automatically.

## Complete CRD example

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: foos.example.io              # must be {plural}.{group}
spec:
  group: example.io
  names:
    kind: Foo
    plural: foos
    singular: foo
    shortNames: [fo]
    categories: [all]                # shows in kubectl get all
  scope: Namespaced                  # or Cluster
  versions:
  - name: v1
    served: true
    storage: true                    # only one version can be the storage version
    subresources:
      status: {}                     # /status subresource (separate RBAC + write path)
      scale:                         # /scale subresource (HPA integration)
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
        labelSelectorPath: .status.selector
    additionalPrinterColumns:
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: [replicas, image]
            properties:
              replicas:
                type: integer
                minimum: 0
                maximum: 100
                default: 1
              image:
                type: string
                pattern: '^[a-z0-9/.:@-]+$'
              config:
                type: object
                x-kubernetes-preserve-unknown-fields: true   # allow arbitrary nested fields
          status:
            type: object
            properties:
              phase:
                type: string
                enum: [Pending, Running, Failed, Succeeded]
              observedGeneration:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  required: [type, status]
                  properties:
                    type:               {type: string}
                    status:             {type: string, enum: [True, False, Unknown]}
                    reason:             {type: string}
                    message:            {type: string}
                    lastTransitionTime: {type: string, format: date-time}
        x-kubernetes-validations:
        - rule: "self.spec.replicas >= 1 || self.spec.image == ''"
          message: "replicas must be at least 1 when image is set"
```

## Structural schema

Required for `apiextensions.k8s.io/v1` CRDs (the only version since 1.22). Rules:

- Every field must have a `type`
- No nested `allOf`/`anyOf`/`oneOf` at the top level (they can appear in property definitions)
- `additionalProperties: true` is not allowed at the top level

The structural schema enables:

- **Pruning** — unknown fields are silently dropped on write
- **Defaulting** — `default:` values are applied server-side
- **Server-side validation** — no admission webhook needed for schema errors
- **SSA** — structural schema is required for Server-Side Apply field tracking

## CEL validation

*GA since 1.29.* `x-kubernetes-validations` runs CEL expressions in the API server — no webhook, no network call, no availability dependency.

```yaml
x-kubernetes-validations:
# Transition rule — only allowed if replicas goes to 0
- rule: "oldSelf.spec.image == self.spec.image || self.spec.replicas == 0"
  message: "cannot change image while running"
  reason: FieldValueForbidden
  fieldPath: .spec.image

# Format rule
- rule: "self.spec.endpoint.startsWith('https://')"
  messageExpression: "'endpoint must use HTTPS, got: ' + self.spec.endpoint"

# Cross-field validation
- rule: "self.spec.maxReplicas >= self.spec.minReplicas"
  message: "maxReplicas must be >= minReplicas"
```

CEL variables:

| Variable | Available | Meaning |
|---|---|---|
| `self` | Always | The object being validated (new value) |
| `oldSelf` | On UPDATE only | The previous value |
| `request` | Future (not yet) | Request metadata |

### CEL cost budget

The API server enforces a CEL execution cost budget per object (to prevent DoS). Expensive operations (regex, string ops on large fields) may exceed the budget. Use `x-kubernetes-validations` at the most specific level possible (on the field, not the root).

### CEL variables (1.30)

Reusable computed values to avoid repeating expensive expressions:

```yaml
x-kubernetes-validations:
- rule: "metrics.all(m, m.value >= 0)"
  message: "all metric values must be non-negative"
variables:
- name: metrics
  expression: "self.spec.metrics.filter(m, m.type == 'Resource')"
```

## Defaulting

Set `default:` in the schema. Applied by the API server:

- On CREATE: missing fields get their defaults
- On READ: fields that existed before the default was added get their defaults injected (enables schema evolution)

```yaml
properties:
  replicas:
    type: integer
    default: 1
  config:
    type: object
    default: {}
    properties:
      timeout:
        type: integer
        default: 30
```

## Status subresource

When `subresources.status: {}` is set:

- `PUT /apis/example.io/v1/namespaces/ns/foos/name` ignores changes to `.status`
- `PUT /apis/example.io/v1/namespaces/ns/foos/name/status` ignores changes to `.spec`
- Separate RBAC: `foos` vs `foos/status`

This prevents a user with only `foos` write access from updating status, and prevents a controller updating status from accidentally overwriting spec.

In controller-runtime:

```go
// Update spec (ignores status changes):
r.Update(ctx, obj)

// Update status only (uses /status subresource):
r.Status().Update(ctx, obj)
```

## Printer columns

Additional columns in `kubectl get` output:

```yaml
additionalPrinterColumns:
- name: Replicas
  type: integer
  jsonPath: .spec.replicas
- name: Ready
  type: integer
  jsonPath: .status.readyReplicas
- name: Phase
  type: string
  jsonPath: .status.phase
- name: Age
  type: date
  jsonPath: .metadata.creationTimestamp
- name: Image
  type: string
  jsonPath: .spec.image
  priority: 1        # shown only in kubectl get -o wide
```

## Categories

```yaml
names:
  categories: [all, myplatform]
```

`kubectl get all` shows your CRD. `kubectl get myplatform` shows all CRs in your platform category. Useful for grouping related CRDs.

## Finalizer patterns

The controller adds its finalizer on create/adopt:

```go
// On reconcile, if object is not being deleted:
if !controllerutil.ContainsFinalizer(obj, myFinalizer) {
    controllerutil.AddFinalizer(obj, myFinalizer)
    return ctrl.Result{}, r.Update(ctx, obj)
}

// If being deleted:
if !obj.DeletionTimestamp.IsZero() {
    if err := r.cleanup(ctx, obj); err != nil {
        return ctrl.Result{}, err
    }
    controllerutil.RemoveFinalizer(obj, myFinalizer)
    return ctrl.Result{}, r.Update(ctx, obj)
}
```
