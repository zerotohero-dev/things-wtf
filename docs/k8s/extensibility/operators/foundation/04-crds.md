# 04 · CRDs — Extending the Kubernetes API

A **CustomResourceDefinition (CRD)** is a Kubernetes object that registers a new
resource type with the API server. Once applied, your cluster knows about
`SpikeConfig` objects just like it knows about Pods — with full REST endpoints,
watch streams, RBAC, and validation.

!!! info "Mental model"

    Kubernetes ships with a vocabulary of objects: Pod, Service, Deployment, etc.
    A CRD is how you **add new words to that vocabulary**. After you install a CRD,
    `kubectl get spikeconfigs` works the same way `kubectl get pods` works — because
    the API server is now natively serving that resource.

---

## Full CRD manifest with annotations

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  # Name must be: {plural}.{group}
  name: spikeconfigs.spike.io
spec:
  group: spike.io
  names:
    kind: SpikeConfig        # CamelCase, used in YAML apiVersion/kind
    plural: spikeconfigs     # lowercase plural, used in URLs and kubectl
    singular: spikeconfig    # lowercase singular
    shortNames: ["sc"]       # kubectl get sc  works now
  scope: Namespaced          # or Cluster
  versions:
    - name: v1alpha1
      served: true           # API server serves requests for this version
      storage: true          # This is the version stored in etcd (only one allowed)
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: ["workloadId"]
              properties:
                workloadId:
                  type: string
                  pattern: "^spiffe://"     # regex validation at API server level
                ttl:
                  type: integer
                  minimum: 3600
                  default: 86400            # injected if field omitted
            status:
              type: object
              # Lets the controller freely write to status
              x-kubernetes-preserve-unknown-fields: true

      # Critical — see explanation below
      subresources:
        status: {}

      additionalPrinterColumns:
        - name: WorkloadID
          type: string
          jsonPath: .spec.workloadId
        - name: Phase
          type: string
          jsonPath: .status.phase
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
```

---

## The status subresource — why it matters

Without `subresources: status: {}`, spec and status share the same API endpoint.
This creates two serious problems:

1. A user running `kubectl apply` can accidentally overwrite status fields
2. A controller updating status triggers a `generation` increment, which
   re-triggers reconciliation in a feedback loop

With the status subresource enabled, `/status` becomes a *separate endpoint*.
Controllers call `r.Status().Update()` which hits `/status` only — this does **not**
increment `metadata.generation`. Users calling the main endpoint cannot touch
status fields.

!!! danger "Always declare the status subresource"

    If you forget this and your controller calls `r.Status().Patch()`, it silently
    falls back to patching the main endpoint, increments the generation, triggers
    another reconcile, and you have an infinite loop. Always declare
    `subresources: status: {}` in every CRD.

---

## Structural schema

In modern Kubernetes (1.15+), CRDs require a **structural schema**: a valid
OpenAPI v3 schema with explicit types for every field. The structural schema
requirement lets the API server:

- Prune unknown fields (so typos don't silently pass through)
- Enforce field validation at admission time, before your controller even runs
- Generate accurate `kubectl explain spikeconfig.spec` docs

You cannot use bare `x-kubernetes-preserve-unknown-fields: true` at the top
level. It must be scoped to specific fields where you genuinely need it (like
the status section, which the controller owns entirely).

---

## Field validation at admission time

Schema constraints are enforced *before* your controller ever sees the object.
This means:

- A `SpikeConfig` with `workloadId: "not-a-spiffe-id"` is rejected immediately
  with a clear error message from the API server
- Your controller never has to defensively validate the spec — the API server
  already did it

This is intentional. Think of schema validation as compile-time type checking
for your API.

---

## CRD versioning

??? example "Deep dive: versioning and conversion webhooks"

    As your CRD evolves, you'll add new versions. A CRD can serve multiple API
    versions simultaneously, but only one is the **storage version** (what's
    actually written to etcd). When a client requests a non-storage version, the
    API server either uses the `none` conversion strategy (only works if schemas
    are identical) or calls your **conversion webhook**.

    The standard pattern is **Hub and Spoke**: one version (usually the latest
    stable one) is the Hub. All other versions are Spokes. Every Spoke must
    implement `ConvertTo(hub)` and `ConvertFrom(hub)`. This means conversion
    between any two spokes always goes through the hub, keeping the code
    manageable.

    **Migrating the storage version** is a multi-step process:

    1. Add the new version as `served: true, storage: false`
    2. Deploy your conversion webhook
    3. Make the new version `storage: true`
    4. Run the storage migration job to rewrite all objects in etcd
    5. Eventually deprecate and remove the old version

    The `kube-storage-version-migrator` handles step 4.

    !!! warning "Platform gotcha"

        Removing a served version from a CRD is a breaking change. If any
        client (another controller, a GitOps tool, a Helm chart) is using that
        version, it will break immediately. Track your CRD consumers before
        deprecating versions.
