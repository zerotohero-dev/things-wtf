---
title: Node Agent and Kopia
---

The `node-agent` `DaemonSet` provides file-level volume backup/restore using 
Kopia. This is the recommended path for workloads where CSI snapshots are 
unavailable or too coarse-grained.

## Architecture

`node-agent` runs on every node. When a `DataUpload`/`DataDownload` CRD is 
created, `velero-server` selects the node-agent instance running on the 
**same node as the pod whose PVC needs backing up**.

```
velero-server
  │  creates DataUpload CRD (spec.node = "node-A")
  │
  ▼
node-agent pod on node-A
  │  DataUploadController reconciles
  │  mounts PVC via hostPath: /var/lib/kubelet/pods/.../volumes/...
  │
  ▼ (Kopia client)
Kopia Repository on ObjectStore (BSL)
```

**`node-agent` must run on the same node as the pod whose PVC it's backing up**, 
because it accesses the PVC via `hostPath` through the kubelet volume manager 
paths (*typically `/var/lib/kubelet/pods/<pod-uid>/volumes/<plugin>/<volume-name>`*). 
The node-agent DaemonSet mounts `/host_pods` pointing at the kubelet pods 
directory.

## Kopia fundamentals

[Kopia](https://kopia.io) is a content-addressed, deduplicated backup engine. 

Velero embeds Kopia as a Go library (*not as an external binary, unlike the 
old [Restic](https://restic.net/) integration which shelled out to a 
`restic` binary*). 

Here are some key concepts:

**Repository**: The central storage entity. Velero creates one Kopia repository 
per BSL, shared by all node-agent instances. Repository access requires a 
password stored in a Kubernetes Secret (`velero-repo-credentials` by default).

**Snapshot**: Each `DataUpload` creates one Kopia snapshot: a versioned tree of 
content hashes. Deduplication happens content-addressably across snapshots: 
unchanged blocks are never re-uploaded.

**Content-Addressable Storage**: File data is chunked, hashed 
(*BLAKE3 or SHA256*), and stored by hash. If two pods have identical files, 
those bytes are stored once. This makes incremental backups very efficient 
for large PVCs with small change sets.

**Repository maintenance**: Kopia repositories accumulate unreferenced content 
when old snapshots are deleted. `maintenance run` (full/quick) prunes this. 
Velero runs maintenance automatically via `BackupRepositoryController`, but 
you need to understand it for large-scale deployments where maintenance can lag.

## DataUpload and DataDownload CRDs

These CRDs are created by `velero-server` and reconciled by `node-agent`. They 
carry the specifics of what to upload/download and status back to 
`velero-server`.

| Field                        | Type       | Description                                                                          |
|------------------------------|------------|--------------------------------------------------------------------------------------|
| `spec.snapshotType`          | `string`   | `CSI` (current) or `Restic` (*legacy*). Determines which uploader is used.           |
| `spec.sourceNamespace`       | `string`   | Namespace of the PVC being backed up.                                                |
| `spec.sourcePVC`             | `string`   | Name of the PVC. node-agent resolves this to a host path.                            |
| `spec.backupStorageLocation` | `string`   | Which BSL to write Kopia repository data to.                                         |
| `spec.operationTimeout`      | `duration` | How long node-agent waits before failing the upload. Tune for large PVCs.            |
| `spec.node`                  | `string`   | Target node name. node-agent only reconciles DataUploads targeted at its own node.   |
| `status.snapshotID`          | `string`   | Kopia snapshot ID written by node-agent on success. Used by DataDownload to restore. |
| `status.progress`            | `Progress` | `BytesDone / TotalBytes`: live progress from the Kopia upload stream.                |

## `node-agent` Configuration

```yaml
# ConfigMap velero/node-agent
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-agent
  namespace: velero
data:
  # Max concurrent Kopia operations per node
  concurrentRepoOperations: "3"
  # Kopia upload workers per operation
  parallelFilesUpload: "10"
  # Timeout for acquiring repository lock
  backupRepositoryLockCheckTimeout: "1m"
  # How many maintenance records to keep
  keepLatestMaintenance: "3"
```

## Kopia Repository Password Management

```bash
# Default secret created by velero install
kubectl get secret -n velero velero-repo-credentials -o yaml

# Rotate the password (requires all node-agents to restart to pick up the new secret)
kubectl create secret generic velero-repo-credentials \
  --from-literal=repository-password="$(openssl rand -base64 32)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

!!! warning "Repository Password Loss"
    If the `velero-repo-credentials` secret is lost and no backup of it exists, 
    the Kopia repository is permanently unreadable. Include this secret in your 
    cluster secrets backup strategy.

## Monitoring Uploads

```bash
# Watch DataUpload objects for active backups
kubectl get dataupload -n velero -w

# Progress for a specific upload
kubectl get dataupload -n velero my-upload -o jsonpath='{.status.progress}'

# node-agent logs on the relevant node
kubectl logs -n velero -l name=node-agent --field-selector spec.nodeName=<node-name>
```

## Data Mover Microservice Model (*modern path*)

For CSI-based volumes, Velero now uses a **data mover microservice** pattern 
instead of the node-agent DaemonSet. This is the recommended path for new 
deployments:

```
velero-server
  │  PVCBackupItemAction creates:
  │    1. VolumeSnapshot
  │    2. DataUpload CR
  │
  ▼
DataUploadController
  │  Creates intermediate PVC from snapshot
  │  Spawns data mover pod mounting that PVC
  │
  ▼
Data Mover Pod (BackupMicroService)
  │  Connects to Kopia repository
  │  Reads data from mounted PVC
  │  Uploads to BSL
  │  Emits completion event with snapshotID
  │
  ▼
DataUploadController marks DataUpload Completed
Cleans up intermediate PVC + mover pod
```

**Key differences from node-agent DaemonSet path:**

| Aspect              | Node-Agent (legacy)              | Data Mover (modern)                    |
|---------------------|----------------------------------|----------------------------------------|
| Pod model           | DaemonSet (always running)       | Per-operation pod (scale to zero)      |
| Volume access       | hostPath via kubelet dirs         | PVC from CSI snapshot                  |
| CRDs                | PodVolumeBackup/Restore          | DataUpload/DataDownload (v2alpha1)     |
| Concurrency control | Per-node concurrency config      | VGDP counter per node                  |
| Result reporting    | CR status update                 | Kubernetes Events                      |
| CSI required        | No                               | Yes (snapshot capability)              |

!!! info "Both paths coexist"
    The node-agent DaemonSet path is still used for non-CSI volumes and for 
    the `defaultVolumesToFsBackup` option. The data mover microservice path 
    is used when CSI snapshots + data movement are enabled 
    (`snapshotMoveData: true`).

## Restic Migration

If you're on a pre-v1.13 deployment using Restic:

```bash
# Migrate existing Restic backups to Kopia-readable format
velero backup-location set default --provider velero.io/aws  # or your provider
# Restic repos and Kopia repos are incompatible — old Restic backups
# can still be RESTORED with the Restic uploader even after switching to Kopia
# for new backups. Set spec.uploaderType: restic on the restore if needed.
```

## Next Up

[CSI Snapshots](csi-snapshots.md)