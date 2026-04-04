---
title: CSI Snapshot Integration
---

CSI `VolumeSnapshot`s are the recommended volume backup mechanism for clusters 
with CSI drivers that support snapshots. For example, this is the primary path 
for vSphere CSI in VCF.

## Mechanism

Velero's CSI snapshot integration works through the standard Kubernetes 
`snapshot.storage.k8s.io` API: it does not call the CSI driver directly.

### Backup flow

**1. Velero creates a VolumeSnapshot**

The built-in `csi-pvc-backupitem-action` `BackupItemAction` creates 
a `VolumeSnapshot` resource in the same namespace as the PVC. 

The VolumeSnapshot references a `VolumeSnapshotClass` that must exist in the 
cluster.

**2. CSI external-snapshotter takes over**

The `volume-snapshot-controller` (*part of the standard CSI snapshot sidecar 
chain: not part of Velero*) reconciles the VolumeSnapshot, calls the CSI 
driver's `CreateSnapshot` RPC, and creates a `VolumeSnapshotContent` with the 
actual snapshot handle from the storage system.

**3. Velero polls for ReadyToUse**

Velero polls the `VolumeSnapshot` until `status.readyToUse = true`. 
The timeout is configurable via `spec.csiSnapshotTimeout` on the `Backup`. 

For thick-provisioned volumes on some storage backends, this can take minutes.

**4. Snapshot metadata is backed up**

Velero serializes the VolumeSnapshot and VolumeSnapshotContent objects into the 
backup tarball AND writes a separate `csi-volumesnapshots.json.gz` file to the 
BSL. This enables restoration of snapshot bindings in a new cluster.

### Restore Flow

**1. VolumeSnapshotContent pre-created**

On restore, Velero creates the `VolumeSnapshotContent` first 
(*with `deletionPolicy: Retain` to preserve the underlying snapshot*), 
then creates the `VolumeSnapshot` referencing it.

**2. PVC bound to snapshot**

The PVC is created with a `dataSource` pointing at the `VolumeSnapshot`. 

The CSI driver's `CreateVolumeFromSnapshot` RPC is triggered when the PVC is 
bound.

## Required cluster components

- **CSI driver** with snapshot capability (*`CREATE_DELETE_SNAPSHOT` in the 
  driver's capabilities*)
- **`volume-snapshot-controller`**: the Kubernetes-standard external controller 
  (*not part of Velero; install separately or verify your cluster ships it*)
- **`snapshot.storage.k8s.io` CRDs**: `VolumeSnapshot`, `VolumeSnapshotContent`, 
  `VolumeSnapshotClass`
- **VolumeSnapshotClass** with the correct driver name and Velero label

## VolumeSnapshotClass configuration

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: vsphere-csi-snapshotclass
  labels:
    # Velero discovers this class by this label
    velero.io/csi-volumesnapshot-class: "true"
driver: csi.vsphere.volume        # vSphere CSI driver name
deletionPolicy: Retain            # CRITICAL — see warning below
parameters:
  # vSphere CSI specific
  csi.storage.k8s.io/volumesnapshot/name: "${volumesnapshot.name}"
  csi.storage.k8s.io/volumesnapshot/namespace: "${volumesnapshot.namespace}"
```

!!! danger "deletionPolicy: Retain is mandatory"
    Velero creates `VolumeSnapshot` objects, serializes them, and then deletes 
    the in-cluster objects after the backup. 

    With `deletionPolicy: Delete`, deleting the `VolumeSnapshot` object triggers 
    the CSI driver to delete the actual storage snapshot immediately: your 
    backup loses its volume data. **Always use `deletionPolicy: Retain` on 
    `VolumeSnapshotClass`es used with Velero.**

## CSI snapshot vs Kopia: decision guide

| Factor                  | CSI Snapshot                                    | Kopia File-Level                           |
|-------------------------|-------------------------------------------------|--------------------------------------------|
| Speed                   | Very fast (storage-level COW)                   | Slower (reads all changed files)           |
| Deduplication           | Storage-system dependent                        | Content-addressable, cross-PVC dedup       |
| Cross-cluster restore   | Requires same storage system or snapshot export | Works anywhere (just needs object store)   |
| Application consistency | Requires storage freeze or hooks                | Requires hooks for consistency             |
| CSI driver required     | Yes, with snapshot capability                   | No (just volume mount access)              |
| Large PVC performance   | Excellent (snapshot is near-instant)            | Proportional to changed data size          |
| VCF vSphere CSI         | Supported (via FCD snapshots)                   | Supported (requires privileged node-agent) |
| Backup portability      | Low (snapshot tied to storage system)           | High (data in object store)                |

**Rule of thumb**: Use CSI snapshots for large PVCs in same-cluster or 
same-datacenter restore scenarios. Use Kopia for cross-datacenter migration, 
cloud-agnostic portability, or when CSI snapshot support isn't available.

## vSphere CSI specifics

vSphere CSI uses **First-Class Disks (FCDs)** — also known as Improved 
Virtual Disks (IVDs) — as the underlying storage primitive for PVCs. FCDs 
are vSphere-managed disk objects that exist independently of VMs, enabling 
snapshot, clone, and migration operations at the storage layer without 
requiring a VM to be attached. CSI snapshots via Velero interact with vCenter through the CSI 
sidecar chain:

```
Velero
  └──► VolumeSnapshot (K8s object)
         └──► volume-snapshot-controller
                └──► csi.vsphere.volume driver
                       └──► vCenter API: CreateSnapshot(FCD)
```

**Known vSphere limitations**:

- Older vSphere versions (`pre-7.0 U3`) limit FCDs to 3 snapshots per disk
- Cross-datastore restore requires a storage vMotion step: the CSI restore may 
  be slower than expected
- Snapshot operations are synchronous in vCenter; `csiSnapshotTimeout` 
  should be set to at least `10m` for large disks

```yaml
# Backup spec for vSphere environments
spec:
  csiSnapshotTimeout: 10m   # default is 10m, increase for large disks
  snapshotMoveData: false    # true = copy snapshot data to BSL via Kopia (snapshot export)
```

## Snapshot Data Movement (*optional*)

Setting `spec.snapshotMoveData: true` on a `Backup` triggers Velero to copy the 
snapshot data into the BSL via Kopia after the CSI snapshot is created. This 
gives you the best of both worlds: fast snapshot creation and portable BSL-stored 
data. It does consume more time and bandwidth.

```yaml
spec:
  snapshotMoveData: true       # copy snapshot data to BSL after creation
  csiSnapshotTimeout: 10m
  defaultVolumesToFsBackup: false
```

## Troubleshooting

```bash
# Check VolumeSnapshot status during backup
kubectl get volumesnapshot -A -w

# Check VolumeSnapshotContent for the snapshot handle
kubectl get volumesnapshotcontent -o yaml | grep snapshotHandle

# Check if volume-snapshot-controller is running
kubectl get pods -n kube-system | grep snapshot-controller

# Verify VolumeSnapshotClass is labeled correctly
kubectl get volumesnapshotclass -L velero.io/csi-volumesnapshot-class
```

## Next Up

[Codebase Tour](../contributing/codebase-tour.md)