# 19 · Operator Lifecycle Management

Operators are infrastructure software. They need the same rigour around build,
release, upgrade, and rollback that you'd apply to any platform component.

---

## Build and release pipeline

```bash
# 1. Verify all generated files are current
make generate manifests
git diff --exit-code   # Fail CI if generated files weren't committed

# 2. Run tests
make test

# 3. Build and push image
IMG=ghcr.io/your-org/spike-operator:v0.2.0
make docker-build docker-push IMG=${IMG}

# 4. Generate the single-file install bundle
make build-installer IMG=${IMG}
# Produces: dist/install.yaml — CRDs + RBAC + Deployment in one file

# 5. Deploy and verify rollout
kubectl apply -f dist/install.yaml
kubectl rollout status deploy/spike-operator -n spike-system --timeout=120s
```

### Semantic versioning for operators

Follow semver strictly:

- **Patch** (`v0.1.1`): bug fixes, no API or behavior changes
- **Minor** (`v0.2.0`): new features, backward-compatible API additions
- **Major** (`v1.0.0`, `v2.0.0`): breaking API changes, new storage versions

---

## CRD upgrade strategy

CRD upgrades require more care than application upgrades because CRDs are
cluster-wide and affect all namespaces immediately.

| Change type | Safety | Procedure |
|---|---|---|
| New optional field | ✅ Safe | Apply directly |
| New field with schema default | ✅ Safe | Apply directly |
| New required field without default | ❌ Breaking | Must add default or make optional |
| Tighter validation (new pattern/min/max) | ⚠️ Breaking for existing objects | Stage via webhook, not schema |
| New served version | ✅ Safe | Add as `served: true, storage: false` |
| Flip storage version | ⚠️ Requires migration | Deploy conversion webhook first |
| Remove a served version | ❌ Breaking | Deprecate for one release minimum |
| Remove a field | ❌ Breaking | Never from current storage version |

!!! danger "Never add a required field without a schema default"

    Adding a required field to a CRD is immediately breaking for existing objects.
    Every existing object in etcd now fails validation on any update — users cannot
    change anything until they add the new field. Always pair new required fields
    with a `+kubebuilder:default=value` marker so the API server injects the default
    for existing objects on read.

---

## The Helm + CRDs trap

!!! danger "Helm does not upgrade CRDs"

    Helm installs CRDs from the `crds/` directory on `helm install`, but subsequent
    `helm upgrade` runs **do not apply CRD changes**. Helm treats CRDs as immutable
    after installation.

    If your CRD schema changes between chart versions, users will run the new
    operator against the old CRD schema — with undefined and potentially dangerous
    behavior.

    **Solutions in common use:**

    1. **Separate Kustomization for CRDs** (Flux): a `Kustomization` that installs
       CRDs runs before the `HelmRelease`. Flux respects the `dependsOn` field.

    2. **HelmRelease `crds: CreateReplace` policy**: Flux's helm-controller applies
       CRDs before reconciling the release when this is set.

    3. **Pre-upgrade Helm hook**: a Job with `helm.sh/hook: pre-upgrade` that
       applies the CRD manifests before the chart is processed.

    4. **Manual runbook step**: documented, enforced in your release process.

    Pick one and be consistent. Option 2 is the simplest if you're already on Flux.

---

## Rolling back an operator

!!! warning "Rollbacks are more complex than for stateless apps"

    The operator may have written status fields or applied schema changes that
    the old version doesn't understand. Always test the downgrade path in staging.

    Rollback procedure:

    1. Roll back the Deployment image: `kubectl rollout undo deploy/spike-operator -n spike-system`
    2. If the CRD schema changed: roll back the CRD too, or verify the old version
       handles new fields gracefully (they should — use `+optional` and `omitempty`)
    3. Verify all objects are reconciling at the previous version (check metrics)
    4. Fields added in the newer version remain in etcd — the old version must
       ignore them cleanly (Go's JSON decoder ignores unknown fields by default)

---

## Storage version migration

When you change the storage version of a CRD (e.g., from `v1alpha1` to `v1`),
existing objects in etcd remain in the old version until migrated:

```bash
# 1. Install the kube-storage-version-migrator
kubectl apply -f https://github.com/kubernetes-sigs/kube-storage-version-migrator/releases/latest/download/deploy.yaml

# 2. Create a migration trigger for your CRD
cat <<EOF | kubectl apply -f -
apiVersion: migration.k8s.io/v1alpha1
kind: StorageVersionMigration
metadata:
  name: spikeconfigs-migration
spec:
  resource:
    group: spike.io
    resource: spikeconfigs
    version: v1alpha1
EOF

# 3. Watch migration progress
kubectl get storageversionmigration spikeconfigs-migration -w
```

After migration, all objects are stored in the new version. You can then safely
remove the old version from `served: true` after one deprecation period.
