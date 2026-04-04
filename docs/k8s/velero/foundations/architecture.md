---
title: Architecture
---

Velero is a single binary that runs both the server-side controller and the 
CLI. Understanding the internal process model is essential before reading the code.

## Process topology

```
┌─────────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                              │
│                                                                 │
│  ┌── namespace: velero ──────────────────────────────────────┐  │
│  │                                                           │  │
│  │  ┌─── velero-server pod ────┐  ┌─── node-agent DaemonSet─┐│  │
│  │  │  BackupController        │  │  DataUploadController   ││  │
│  │  │  RestoreController       │  │  DataDownloadController ││  │
│  │  │  ScheduleController      │  │  Kopia repository engine││  │
│  │  │  GCController            │  │  hostPath: / (ro)       ││  │
│  │  │  BSLController           │  └─────────────────────────┘│  │
│  │  └──────────────────────────┘                             │  │
│  │                                                           │  │
│  │  ┌─── API Server (controller-runtime informers) ─────────┐│  │
│  │  └───────────────────────────────────────────────────────┘│  │
│  │                                                           │  │
│  │  ┌─── Velero CRDs (etcd) ──┐  ┌─── PVC/VolumeSnapshot ──┐ │  │
│  │  └─────────────────────────┘  └─────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
          │                                    │
          ▼ (go-plugin / gRPC)                 ▼
   ┌─── Plugin process ───┐          ┌─── Object Storage ───┐
   │  ObjectStore impl    │──────────│  S3 / GCS / Azure /  │
   │  VolumeSnapshotter   │          │  custom              │
   └──────────────────────┘          └──────────────────────┘
```

## Controllers

Velero uses [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime) 
(*the same library as [operator-sdk](https://sdk.operatorframework.io/)*). 
Each CRD has one or more reconcilers that watch for changes and drive state.

Velero has **19 controllers** across ~10 CRDs. Some CRDs are reconciled by 
multiple controllers at different lifecycle phases. The full inventory:

| Controller                      | Watches                       | Action                                                              |
|---------------------------------|-------------------------------|---------------------------------------------------------------------|
| `BackupQueueController`         | Backup CRD (New)              | Queue ordering, namespace conflict detection, concurrency limits    |
| `BackupController`              | Backup CRD (ReadyToStart)     | Executes backup via `backup.Backup`                                 |
| `BackupOperationsController`    | Backup CRD (InProgress)       | Polls async plugin operations every 10s                             |
| `BackupFinalizerController`     | Backup CRD (Finalizing)       | Finalizes item actions, uploads metadata                            |
| `RestoreController`             | Restore CRD                   | Downloads backup, replays resources via dynamic client              |
| `RestoreOperationsController`   | Restore CRD                   | Polls async plugin operations every 10s                             |
| `RestoreFinalizerController`    | Restore CRD (Finalizing)      | Runs finalization hooks, uploads results                            |
| `ScheduleController`            | Schedule CRD                  | Creates Backup objects on cron cadence, skip/pause logic            |
| `GCController`                  | Backup CRD (expired)          | TTL-based expiration, creates DeleteBackupRequests (every 60m)      |
| `BackupSyncController`          | BackupStorageLocation         | Syncs Backup objects from BSL into cluster (cross-cluster restores) |
| `BackupDeletionController`      | DeleteBackupRequest CRD       | Handles explicit backup deletion requests                           |
| `BSLController`                 | BackupStorageLocation         | Validates storage connectivity every 10s                            |
| `BackupRepoController`          | BackupRepository CRD          | Establishes/maintains repos, triggers Kopia maintenance             |
| `DataUploadController`          | DataUpload CRD                | Manages backup data mover pods (CSI path)                           |
| `DataDownloadController`        | DataDownload CRD              | Manages restore data mover pods (CSI path)                          |
| `PodVolumeBackupController`     | PodVolumeBackup CRD           | Legacy FS-based volume backup via node-agent                        |
| `PodVolumeRestoreController`    | PodVolumeRestore CRD          | Legacy FS-based volume restore via node-agent                       |
| `DownloadRequestController`     | DownloadRequest CRD           | Generates signed URLs for backup/restore artifacts                  |
| `ServerStatusRequestController` | ServerStatusRequest CRD       | Returns server version and installed plugins                        |

!!! info "Multiple controllers per CRD"
    A single Backup CRD is reconciled by **4 controllers in sequence**: 
    Queue → Backup → Operations → Finalizer. Understanding which controller 
    owns which phase transition is essential for debugging and contributing. 
    See [Controller Deep Dive](../internals/controllers.md).

## Plugin Process Model

Velero uses [hashicorp/go-plugin](https://github.com/hashicorp/go-plugin) to r
un plugins as **separate OS processes** communicating over gRPC. 

This design has deliberate consequences:

- **Crash isolation**: a crashing plugin doesn't take down `velero-server`.
- **Language agnostic**: plugins can be written in any language that speaks 
  gRPC (*though the Go SDK is the only officially supported one*).
- **No hot reload**: plugins are discovered at startup from the 
  `/plugins` directory in the velero pod. **Changing plugins requires a pod 
  restart**.

```go
// pkg/client/factory.go: plugin manager setup (simplified)
pluginManager := clientmgmt.NewManager(logger, logLevel, pluginRegistry)
// Plugin registry scans the /plugins dir in the pod at startup
// Each binary exposes its capabilities via the SDK handshake
objectStore, err := pluginManager.GetObjectStore("velero.io/aws")
snapshotter, err := pluginManager.GetVolumeSnapshotter("velero.io/aws")
```

## velero CLI

The `velero` binary is the same binary as the server: it branches on 
subcommand. `velero server` starts the controller manager. 

The CLI communicates with the cluster 
**exclusively through CRD objects and the API server**: 
there is no direct channel to the velero-server pod.

!!! tip "Prototyping Tip"
    Because CLI actions work through CRDs, you can prototype behavior by 
    manually creating `YAML` and watching reconciliation: 
    no UI or CLI shim needed.

## HA and Leadership Election

When running multiple replicas of velero-server (*for HA*), 
`controller-runtime`'s built-in leader election (*via Kubernetes leases*) 
ensures only one replica runs the reconcilers at a time. 

The lease is in the `velero` namespace.

```yaml
# velero server flags for HA
--leader-elect=true
--leader-elect-lease-duration=15s
--leader-elect-renew-deadline=10s
```

## Next Up

[Core CRDs](crds.md)
