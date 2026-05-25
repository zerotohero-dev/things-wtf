# Storage

## The storage object model

```
StorageClass  ←  defines the provisioner + parameters
     ↓
PersistentVolume (PV)  ←  a piece of actual storage, cluster-scoped
     ↑
PersistentVolumeClaim (PVC)  ←  a request for storage, namespace-scoped
     ↑
Pod  ←  mounts the PVC as a volume
```

## PersistentVolume (PV)

Cluster-scoped storage resource. Represents a piece of storage that exists independently of any pod.

```yaml
apiVersion: v1
kind: PersistentVolume
spec:
  capacity: {storage: 50Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain   # Retain | Delete | Recycle(deprecated)
  storageClassName: fast
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-0a1b2c3d4e5f
    fsType: ext4
```

Reclaim policies:

- **Retain** — PV persists after PVC deletion; must be manually reclaimed (delete PV, re-create to re-use)
- **Delete** — CSI driver deletes the backing storage when PVC is deleted
- **Recycle** — deprecated; use dynamic provisioning instead

## PersistentVolumeClaim (PVC)

Namespace-scoped request for storage. Bound to a PV that satisfies its requirements.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: fast
  resources:
    requests: {storage: 10Gi}
  volumeMode: Filesystem    # or Block (raw block device)
```

Binding is 1:1 between PVC and PV — even if the PVC requests less than the PV has. There's no partial allocation at the PV level.

PVC expansion (if `StorageClass.allowVolumeExpansion: true`):

```bash
kubectl patch pvc mydata -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

The CSI driver resizes the volume online (for supported storage backends). The filesystem is expanded when the pod mounts it (or immediately for some backends).

## StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer   # vs Immediate
mountOptions: [noatime]
```

`volumeBindingMode: WaitForFirstConsumer` delays PV provisioning until a pod using the PVC is scheduled. This is critical for topology-aware (zonal) storage — you want the PV provisioned in the same zone as the pod. `Immediate` mode provisions at PVC creation time, before any pod exists, which can put the storage in the wrong zone.

## CSI (Container Storage Interface)

A gRPC spec between the kubelet and a storage driver. The driver runs as a DaemonSet (node plugin) + Deployment (controller plugin).

Driver responsibilities split by component:

**Controller plugin** (Deployment, talks to storage API):

- `CreateVolume` / `DeleteVolume`
- `ControllerPublishVolume` / `ControllerUnpublishVolume` (attach/detach)
- `CreateSnapshot` / `DeleteSnapshot`
- `ControllerExpandVolume`

**Node plugin** (DaemonSet, runs on each node):

- `NodeStageVolume` — mounts to a global path on the node (one mount per volume)
- `NodePublishVolume` — bind-mounts from global path into pod's volume mount
- `NodeExpandVolume` — resize filesystem

**Sidecar controllers** (run alongside the driver, translate K8s events → CSI calls):

`external-provisioner` · `external-attacher` · `external-resizer` · `external-snapshotter` · `node-driver-registrar` · `livenessprobe`

## Access modes

| Mode | Short | Meaning | Typical backend |
|---|---|---|---|
| `ReadWriteOnce` | RWO | Read-write by one node | Block: EBS, GCE PD, Azure Disk |
| `ReadWriteMany` | RWX | Read-write by many nodes | NFS, CephFS, EFS, AzureFile |
| `ReadOnlyMany` | ROX | Read-only by many nodes | Any |
| `ReadWriteOncePod` | RWOP | Read-write by one pod (GA 1.29) | Block volumes with RWOP-capable CSI driver |

RWOP is stricter than RWO — RWO allows multiple pods on the *same node* to mount, RWOP restricts to a single pod cluster-wide.

## Volume types

### In-pod / ephemeral

| Type | Lifecycle | Notes |
|---|---|---|
| `emptyDir` | Pod | Shared scratch space between containers. `medium: Memory` = tmpfs. Size limit via `sizeLimit`. |
| `ephemeral` | Pod | Inline PVC — provisioned dynamically, deleted when pod is deleted. |

### Config injection

| Type | Source |
|---|---|
| `configMap` | ConfigMap data |
| `secret` | Secret data |
| `downwardAPI` | Pod metadata (labels, annotations, resource limits) |
| `projected` | Combines multiple sources into one mount point |

### Persistent

Use PVC volumes:

```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: mydata
    readOnly: false
```

### CSI inline volumes (ephemeral)

For secrets managers and other CSI drivers that provide per-pod ephemeral volumes:

```yaml
volumes:
- name: vault-secret
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: my-secrets
```

## Volume snapshots

Requires `external-snapshotter` and a CSI driver that supports snapshots.

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
spec:
  volumeSnapshotClassName: csi-aws-vsc
  source:
    persistentVolumeClaimName: mydata
```

Restore from snapshot:

```yaml
spec:
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```
