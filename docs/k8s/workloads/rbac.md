# RBAC

Role-Based Access Control. Enabled by default since 1.8; the only authorization mode you should use in production (alongside Node authorization for kubelets).

## Four objects

| Object | Scope | Purpose |
|---|---|---|
| `Role` | Namespace | Defines rules (verbs on resources) within a namespace |
| `ClusterRole` | Cluster | Defines rules cluster-wide, or used cross-namespace via ClusterRoleBinding |
| `RoleBinding` | Namespace | Grants a Role or ClusterRole to subjects within a namespace |
| `ClusterRoleBinding` | Cluster | Grants a ClusterRole to subjects cluster-wide |

Use a `ClusterRole` + `RoleBinding` (not ClusterRoleBinding) to grant namespace-scoped permissions to multiple namespaces using the same rule definition.

## Role & ClusterRole

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: myns
  name: deployment-manager
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]   # sub-resources require separate rules
  verbs: ["get", "create"]
- apiGroups: ["apps"]
  resources: ["deployments/scale"]       # sub-resource
  verbs: ["update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  resourceNames: ["myapp", "myapp-worker"]   # restrict to specific object names
  verbs: ["delete"]
```

All verbs: `get` `list` `watch` `create` `update` `patch` `delete` `deletecollection` `impersonate` `bind` `escalate` `use` (PodSecurityPolicy, deprecated)

`apiGroups: [""]` is the core group. Named groups: `apps`, `batch`, `networking.k8s.io`, `rbac.authorization.k8s.io`, `storage.k8s.io`, `autoscaling`, `policy`, `coordination.k8s.io`, etc.

## RoleBinding & ClusterRoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: myns
  name: grant-deployment-manager
subjects:
- kind: User
  name: jane@example.com      # external user (identity from AuthN layer)
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: platform-team
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: ci-deployer
  namespace: myns              # namespace required for ServiceAccount
roleRef:
  kind: Role                   # or ClusterRole
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
```

!!! warning "roleRef is immutable"
    Once a binding is created, `roleRef` cannot be changed. Delete and recreate to change the role. This prevents privilege escalation via binding mutation.

## Built-in ClusterRoles

| ClusterRole | Access |
|---|---|
| `cluster-admin` | Full access to everything. The `system:masters` group has this permanently, bypassing RBAC. |
| `admin` | Full access within a namespace (edit + grant Roles). |
| `edit` | Read + write most resources except RBAC objects, LimitRanges, ResourceQuotas. |
| `view` | Read most resources except Secrets, RBAC, LimitRanges. |
| `system:node` | Access kubelet needs. Granted via Node authorizer, not RBAC. |
| `system:kube-scheduler` | Scheduler's access. |
| `system:kube-controller-manager` | KCM's access. |

Aggregated ClusterRoles: `admin`, `edit`, `view` support label-based aggregation — add `rbac.authorization.k8s.io/aggregate-to-view: "true"` to a ClusterRole to include its rules in the `view` role.

## ServiceAccounts

Every pod gets a ServiceAccount (default: `default` in its namespace). SA credentials are mounted as a projected `serviceAccountToken` volume.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-operator
  namespace: myns
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123:role/my-operator-role  # IRSA
automountServiceAccountToken: false   # opt out of auto-mount cluster-wide
```

Disable auto-mount for pods that don't need API access:

```yaml
spec:
  automountServiceAccountToken: false
```

### Workload Identity patterns

| Platform | Mechanism |
|---|---|
| AWS | IRSA (IAM Roles for Service Accounts) — SA annotation + OIDC federation |
| GCP | Workload Identity — SA annotation links K8s SA to GCP SA |
| Azure | Workload Identity — same pattern with Azure AD |
| SPIFFE/SPIRE | Platform-agnostic SVID issuance; integrates via CSI driver or projected token |

## Auditing RBAC

```bash
# Can a ServiceAccount do X?
kubectl auth can-i list pods \
  --as=system:serviceaccount:myns:my-operator \
  --namespace=myns

# What can a user do?
kubectl auth can-i --list --as=jane@example.com

# Who can do X?
kubectl get clusterrolebindings,rolebindings -A -o json \
  | jq '.items[] | select(.roleRef.name == "cluster-admin")'

# Idempotent apply of RBAC manifests
kubectl auth reconcile -f rbac.yaml
```

Tools: `rbac-lookup` (by Reactiveops), `kubectl-who-can` (by Aqua), `audit2rbac` (generate RBAC from audit logs).

## Common mistakes

**Granting `cluster-admin` broadly** — use scoped roles. `cluster-admin` bypasses all RBAC checks.

**Forgetting sub-resources** — `pods` permission doesn't include `pods/log` or `pods/exec`. Add explicit rules.

**Using `ClusterRoleBinding` for namespace-scoped work** — use `RoleBinding` + `ClusterRole` to limit blast radius.

**`get` without `list`** — some controllers need both. `get` = single object by name; `list` = query by label selector.

**`watch` without `list`** — informers need both. `list` populates the initial cache; `watch` streams updates.
