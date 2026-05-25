# RBAC from Markers

Place RBAC markers in your controller file. `make manifests` generates the `ClusterRole` YAML in `config/rbac/`. This keeps permissions co-located with the code that needs them — no separate RBAC file to keep in sync.

---

## Full RBAC Marker Set

```go title="internal/controller/webapp_controller.go — RBAC markers"
// ── Primary resource ─────────────────────────────────────────────────────
// +kubebuilder:rbac:groups=apps.example.com,resources=webapps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps.example.com,resources=webapps/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps.example.com,resources=webapps/finalizers,verbs=update

// ── Owned resources ──────────────────────────────────────────────────────
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete

// ── Secondary watches (read-only) ────────────────────────────────────────
// +kubebuilder:rbac:groups=core,resources=configmaps,verbs=get;list;watch
// +kubebuilder:rbac:groups=core,resources=secrets,verbs=get;list;watch

// ── Events ───────────────────────────────────────────────────────────────
// +kubebuilder:rbac:groups=core,resources=events,verbs=create;patch

// ── Leader election ──────────────────────────────────────────────────────
// +kubebuilder:rbac:groups=coordination.k8s.io,resources=leases,verbs=get;list;watch;create;update;patch;delete
```

After adding or changing markers, regenerate:

```bash
make manifests
# → updates config/rbac/role.yaml
```

---

## Marker Syntax Reference

```
// +kubebuilder:rbac:groups=<apiGroup>,resources=<resource>,verbs=<verb>[;<verb>...]
```

| Field | Value | Notes |
|-------|-------|-------|
| `groups` | `core` or `""` for core group | `apps`, `networking.k8s.io`, `coordination.k8s.io`, etc. |
| `resources` | Resource name (plural) | `deployments`, `services`, `configmaps` |
| `verbs` | Semicolon-separated | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection` |
| `namespace` | optional | Restricts to namespace (for Role vs ClusterRole) |
| `resourceNames` | optional | Restrict to specific named resources |

```go
// Namespace-scoped role (generates Role, not ClusterRole)
// +kubebuilder:rbac:groups=core,resources=secrets,verbs=get,namespace=webapp-operator-system

// Restrict to specific resource name
// +kubebuilder:rbac:groups=coordination.k8s.io,resources=leases,verbs=get;update,resourceNames=webapp-operator.example.com
```

---

## Verifying RBAC

```bash
# Verify the operator has the permissions it thinks it has
kubectl auth can-i list deployments \
  --as=system:serviceaccount:webapp-operator-system:webapp-operator-controller-manager

kubectl auth can-i update webapps/status \
  --as=system:serviceaccount:webapp-operator-system:webapp-operator-controller-manager \
  -n production

# See the full generated ClusterRole
kubectl get clusterrole webapp-operator-manager-role -o yaml
```

---

## Principle of Least Privilege

!!! tip "Audit and trim generated permissions"
    kubebuilder scaffolds broad permissions by default. Before going to production:

    - Remove `create;delete` if you only patch
    - Remove `deletecollection` if you never use it
    - Scope to namespace if your operator is namespace-scoped

    ```bash
    # Check what verbs your operator actually uses
    # (look for audit log entries or use kube-rbac-proxy's metrics)
    kubectl logs -n webapp-operator-system deploy/webapp-operator-controller-manager \
      | grep 'resource=' | sort | uniq -c
    ```

---

## Webhook RBAC Markers

If you add conversion or validation webhooks, you'll need additional markers:

```go
// +kubebuilder:webhook:path=/mutate-apps-example-com-v1alpha1-webapp,mutating=true,failurePolicy=fail,sideEffects=None,groups=apps.example.com,resources=webapps,verbs=create;update,versions=v1alpha1,name=mwebapp.kb.io,admissionReviewVersions=v1

// +kubebuilder:webhook:path=/validate-apps-example-com-v1alpha1-webapp,mutating=false,failurePolicy=fail,sideEffects=None,groups=apps.example.com,resources=webapps,verbs=create;update,versions=v1alpha1,name=vwebapp.kb.io,admissionReviewVersions=v1
```

These generate the `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration` in `config/webhook/`.
