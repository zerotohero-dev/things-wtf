# API Versioning

## Stability levels

| Level | Version naming | Enabled by default | API stability guarantees |
|---|---|---|---|
| **Alpha** | `v1alpha1`, `v2alpha3` | No (feature gate) | None. May be dropped or break in any release. |
| **Beta** | `v1beta1`, `v1beta2` | Yes | Not dropped without 9 months or 3 minor releases notice. No arbitrary breaking changes. |
| **GA / Stable** | `v1`, `v2` | Yes | Supported 12 months or 2 minor releases minimum. Breaking changes only via new major version. |

## Deprecation policy

Once a stable API is added, it may not be removed without the minimum deprecation window:

- **Alpha**: no guarantee
- **Beta**: deprecated for ≥9 months or ≥3 minor releases before removal
- **GA**: deprecated for ≥12 months or ≥2 minor releases before removal

**Multiple versions coexist**: when a newer version exists, both are served simultaneously during the deprecation window. The API server converts between them on read/write using the internal (hub) version.

Example: `extensions/v1beta1` Deployments were deprecated in 1.9, removed in 1.16. All `extensions/v1beta1` Deployments were automatically served as `apps/v1` during that window.

`kubectl` prints deprecation warnings from the API server:

```
Warning: apps/v1beta1 Deployment is deprecated; use apps/v1 Deployment
```

## Version skew policy

Kubernetes components have a strict supported skew:

| Component pair | Max skew | Notes |
|---|---|---|
| API server ↔ API server | ±1 minor | During upgrades; all masters must be within 1 minor |
| kubelet ↔ API server | kubelet ≤ apiserver, max -2 | kubelet may never be *newer* than API server |
| kubectl ↔ API server | ±1 minor | Supported range |
| kube-scheduler ↔ API server | scheduler ≤ apiserver | Must not be newer |
| kube-controller-manager ↔ API server | kcm ≤ apiserver | Must not be newer |

Upgrade order: API servers first (in a multi-master cluster, one at a time), then controller-manager/scheduler, then kubelets.

## Feature gates

Boolean flags that control whether alpha/beta features are enabled. Set per-component:

```
kube-apiserver --feature-gates=ServerSideApply=true,ValidatingAdmissionPolicy=true
kubelet        --feature-gates=InPlacePodVerticalScaling=true
```

Lifecycle:

```
Alpha (default=false) → Beta (default=true) → GA (locked=true) → removed
```

Once a feature reaches GA, its gate is locked to `true` and eventually removed from the codebase. You cannot disable GA features.

In 1.29+, component config files are the preferred mechanism over command-line flags.

## Internal version & conversion

The API server maintains an **internal (hub) version** for each group — this is the version used in memory and for cross-version conversion. It's never served externally.

Conversion path:

```
v1alpha1 → internal → v1beta1 → internal → v1
```

Hub-and-spoke reduces N×(N-1) conversion functions to 2×N: each version only needs to know how to convert to/from internal.

For CRDs:

```yaml
versions:
- name: v1
  served: true
  storage: true      # storage version — what gets written to etcd
- name: v1beta1
  served: true
  storage: false     # still served; converted from v1 on read
```

If a field exists in v1 but not v1beta1, the conversion webhook (or CEL conversion, in future) must handle the lossy conversion gracefully.

## Multi-version CRDs

```yaml
spec:
  versions:
  - name: v2
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        properties:
          spec:
            properties:
              endpoint:    # renamed from v1's "url"
                type: string
  - name: v1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        properties:
          spec:
            properties:
              url:         # old field name
                type: string
  conversion:
    strategy: Webhook
    webhook:
      conversionReviewVersions: [v1]
      clientConfig:
        service: {name: myoperator-webhook, namespace: system, port: 443, path: /convert}
```

The conversion webhook receives a `ConversionReview` object containing objects to convert and a `desiredAPIVersion`. It must handle all version pairs.

### Hub-and-spoke pattern

For N versions, implement conversion through a single hub version to avoid O(N²) conversion functions:

```
v1alpha1 ↔ v2 (hub) ↔ v1beta1
v1alpha2 ↕
v1       ↕
```

Only v2 needs to know about all other versions. All others only need to know v2. Results in 2×(N-1) conversion functions instead of N×(N-1).

## API server flags for version control

```bash
# Disable a specific API group version (e.g., during migration)
--runtime-config=apps/v1beta1=false

# Enable alpha APIs
--runtime-config=api/alpha=true

# Feature gates
--feature-gates=EphemeralContainers=true
```

`--runtime-config` takes comma-separated `group/version=bool` entries. `api/all=false` disables everything except `api/v1`.
