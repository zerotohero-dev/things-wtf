# Core Primitives

## Pod

The smallest schedulable unit. One or more containers that share:

- **Network namespace** — same IP, same port space, communicate over `localhost`
- **UTS namespace** — same hostname
- **PID namespace** — optionally shared (controlled by `spec.shareProcessNamespace`)

The pod's IP is routable within the cluster (flat network model — no NAT between pods).

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    resources:
      requests: {cpu: "100m", memory: "128Mi"}
      limits:   {memory: "256Mi"}          # CPU limit = throttle, not kill
    livenessProbe:
      httpGet: {path: /healthz, port: 8080}
      initialDelaySeconds: 10
      periodSeconds: 15
    readinessProbe:
      httpGet: {path: /ready, port: 8080}
  initContainers:                          # run to completion before app starts
  - name: migration
    image: myapp-migrate:1.0
  volumes:
  - name: data
    emptyDir: {}                           # lifecycle = pod lifetime
```

### The pause container

Every pod has a **sandbox container** (the `pause` binary) created first. It holds the network namespace. All app containers and init containers join it via `--network=container:<pause-id>`. The pause container exists only to pin the netns — if it were killed, all containers would lose their network identity. The kubelet monitors it separately.

### Pod lifecycle

| Phase | Meaning |
|---|---|
| `Pending` | Accepted by API server; waiting for scheduling or image pull |
| `Running` | At least one container is running |
| `Succeeded` | All containers exited 0; won't restart |
| `Failed` | All containers exited; at least one non-zero |
| `Unknown` | Node communication lost |

`restartPolicy` (`Always`, `OnFailure`, `Never`) applies per-container exit within a pod.

!!! warning "Never run naked pods in production"
    Naked pods (no owning controller) are not rescheduled if a node fails. Always use a Deployment, StatefulSet, or Job.

## Node

A Node is a VM or bare metal machine. The API object (`kind: Node`) is created by the cloud-controller-manager or manually registered via `kubelet --register-node`.

Key fields:

```yaml
status:
  capacity:         {cpu: "4", memory: "16Gi", pods: "110"}
  allocatable:      {cpu: "3800m", memory: "14Gi", pods: "110"}  # after system reservations
  conditions:
  - type: Ready      # True = healthy, False = problem, Unknown = no heartbeat
  - type: MemoryPressure
  - type: DiskPressure
  - type: PIDPressure
  nodeInfo:
    kubeletVersion: v1.30.0
    containerRuntimeVersion: containerd://1.7.0
spec:
  taints:
  - key: node-role.kubernetes.io/control-plane
    effect: NoSchedule
```

The kubelet sends a PATCH to update node status every `nodeStatusUpdatePeriod` (default 10s). The node lifecycle controller marks a node `Unknown` after `node-monitor-grace-period` (default 40s) without a heartbeat, and begins eviction after `pod-eviction-timeout` (default 5m).

## Namespace

Soft multi-tenancy boundary. Namespaces provide:

- **Name scoping** — resources in different namespaces can share names
- **RBAC scope** — Roles and RoleBindings apply within a namespace
- **Quota scope** — `ResourceQuota` and `LimitRange` operate per-namespace
- **NetworkPolicy scope** — policies select pods within a namespace

**Cluster-scoped resources** (no namespace): `Node`, `PersistentVolume`, `ClusterRole`, `ClusterRoleBinding`, `StorageClass`, `IngressClass`, `Namespace`, `CustomResourceDefinition`.

Namespace deletion cascades — all namespaced resources are garbage collected. Uses a finalizer (`kubernetes`) that the namespace controller removes after cleanup.

## Labels & selectors

Labels are arbitrary `key: value` pairs on any object. Key format: `[prefix/]name` where prefix is optional DNS subdomain.

Two selector types:

**Equality-based** — used by Services, Deployments, ReplicaSets:
```
env=prod,tier=frontend
env!=canary
```

**Set-based** — more expressive, used in affinity rules, `kubectl`:
```
env in (prod, staging)
tier notin (frontend)
!canary
```

### Recommended label conventions

```yaml
metadata:
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: helm
```

These are conventions, not enforced. Tooling (Helm, Flux, Argo) uses `managed-by`. Prometheus service discovery typically looks for `app.kubernetes.io/name`.

## Annotations

Non-identifying metadata stored on any object. Unlike labels:

- Not indexed — cannot be used in selectors
- No size limit (practical limit ~256KB per object due to etcd value size)
- Can store arbitrary string values

Common uses:

```yaml
annotations:
  kubectl.kubernetes.io/last-applied-configuration: '...'   # client-side apply state
  deployment.kubernetes.io/revision: "3"                    # rollout history
  prometheus.io/scrape: "true"                              # Prometheus autodiscovery
  cert-manager.io/cluster-issuer: letsencrypt-prod          # cert-manager config
  helm.sh/chart: myapp-1.2.3                                # Helm release info
  fluxcd.io/sync-checksum: abc123                           # Flux sync state
```

## Finalizers

String values in `.metadata.finalizers[]`. The mechanism for controlled deletion:

1. Controller adds its string to `finalizers[]` when it creates/adopts an object
2. When user sends DELETE, the API server sets `deletionTimestamp` but does **not** remove the object from etcd
3. The owning controller sees `deletionTimestamp`, performs cleanup (deletes external resources, waits for child objects, etc.)
4. Controller removes its string from `finalizers[]`
5. When `finalizers[]` is empty, the API server removes the object from etcd

```yaml
metadata:
  finalizers:
  - storage.example.io/cleanup    # custom controller must remove this
  - foregroundDeletion            # built-in: wait for owned objects
```

!!! warning "Orphaned finalizers"
    If a controller is deleted before it can remove its finalizer, the object is permanently stuck in terminating state. Force-remove with:
    ```
    kubectl patch <resource>/<name> -p '{"metadata":{"finalizers":null}}'
    ```
    This skips the cleanup logic — only use when you know external resources are already cleaned up.

## Owner references

The garbage collection chain. Set on child objects to point at their owner:

```yaml
metadata:
  ownerReferences:
  - apiVersion: apps/v1
    kind: ReplicaSet
    name: myapp-7d9f4b8c9
    uid: 550e8400-e29b-41d4-a716-446655440000
    controller: true          # exactly one owner can be the controller
    blockOwnerDeletion: true  # owner deletion blocks until this object is gone
```

The garbage collector controller watches for objects whose owners no longer exist and deletes them. Deletion modes:

- **Background** (default) — owner deleted immediately, GC runs async
- **Foreground** — owner gets a `foregroundDeletion` finalizer, deleted only after all owned objects (with `blockOwnerDeletion: true`) are gone
- **Orphan** — owned objects' `ownerReferences` are cleared, they persist
