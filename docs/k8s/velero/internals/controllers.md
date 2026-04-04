---
title: Controller Deep Dive
---

# Controller Deep Dive

Velero has **19 controllers** reconciling ~10 CRDs. The non-obvious part: 
some CRDs are reconciled by **multiple controllers at different lifecycle 
phases**. Understanding which controller owns which phase transition is 
essential for debugging and contributing.

## Backup Controller Chain

A single Backup CRD is processed by **4 controllers in sequence**:

```
BackupQueueController         BackupController
    │                              │
    │ New → Queued → ReadyToStart  │ ReadyToStart → InProgress
    │ (checks concurrency,         │ (runs backup.Backup:
    │  namespace conflicts)        │  collect items, run plugins,
    │                              │  write tar, upload to BSL)
    │                              │
    ▼                              ▼
BackupOperationsController     BackupFinalizerController
    │                              │
    │ InProgress →                 │ Finalizing → Completed
    │ WaitingForPluginOperations   │ (finalize item actions,
    │ (polls async plugin ops      │  upload final metadata)
    │  every 10s)                  │
```

### BackupQueueController

- **Trigger**: New Backup objects + periodic re-evaluation (1m)
- **Responsibility**: Queue ordering, concurrent backup limit enforcement, 
  namespace conflict detection
- **Transitions**: `New → Queued → ReadyToStart`
- **Key logic**: Two backups covering overlapping namespaces cannot run 
  simultaneously. Uses set intersection on included namespaces.

### BackupController

- **Trigger**: Backup reaches `ReadyToStart`
- **Responsibility**: Execute the backup via `backup.Backup`
- **Transitions**: `ReadyToStart → InProgress`
- **Key logic**: Calls `BackupWithResolvers()` which runs item collection, 
  BackupItemAction plugins, volume snapshots, and tar archiving.

### BackupOperationsController

- **Trigger**: Periodic (10s)
- **Responsibility**: Poll async plugin operations (v2 BIA operations)
- **Transitions**: `InProgress → WaitingForPluginOperations → Finalizing`

### BackupFinalizerController

- **Trigger**: Backup reaches `Finalizing`
- **Responsibility**: Run finalization hooks, upload final metadata to BSL
- **Transitions**: `Finalizing → Completed / PartiallyFailed / Failed`

## Restore Controller Chain

Similar pattern with **3 controllers**:

```
RestoreController              RestoreOperationsController
    │                              │
    │ New → InProgress             │ InProgress →
    │ (unpack tar, restore         │ WaitingForPluginOperations
    │  CRDs first, then all        │ (polls async plugin ops)
    │  resources in priority       │
    │  order)                      ▼
    │                          RestoreFinalizerController
    │                              │
    │                              │ Finalizing → Completed
    │                              │ (finalization hooks,
    │                              │  upload results)
```

## Other Controllers

| Controller                      | Watches                 | Trigger        | Action                                                              |
|---------------------------------|-------------------------|----------------|---------------------------------------------------------------------|
| `ScheduleController`            | Schedule CRD            | Spec + 1m      | Cron evaluation, skip/pause logic, creates Backup objects           |
| `GCController`                  | Backup CRD              | 60m            | TTL-based expiration, creates DeleteBackupRequests                  |
| `BackupSyncController`          | BSL                     | Periodic       | Reads BSL to sync Backup objects into cluster                       |
| `BackupDeletionController`      | DeleteBackupRequest     | Create/update  | Deletes backup from storage, cleans CSI artifacts                   |
| `BSLController`                 | BSL                     | 10s            | Validates storage connectivity, scrubs error messages               |
| `BackupRepoController`          | BackupRepository CRD    | Spec + 5m      | Establishes repos, triggers Kopia maintenance                       |
| `DataUploadController`          | DataUpload CRD          | Create/update  | Manages backup data mover pods (CSI path)                           |
| `DataDownloadController`        | DataDownload CRD        | Create/update  | Manages restore data mover pods (CSI path)                          |
| `PodVolumeBackupController`     | PodVolumeBackup CRD     | Create/update  | Legacy FS-based volume backup via node-agent                        |
| `PodVolumeRestoreController`    | PodVolumeRestore CRD    | Create/update  | Legacy FS-based volume restore via node-agent                       |
| `DownloadRequestController`     | DownloadRequest CRD     | Create/update  | Generates signed URLs for backup/restore artifacts                  |
| `ServerStatusRequestController` | ServerStatusRequest CRD | Create/update  | Returns server version and installed plugins                        |

## Key Files

| File                                         | What it does                                                              |
|----------------------------------------------|---------------------------------------------------------------------------|
| `pkg/controller/backup_controller.go`        | State machine for Backup CRD from ReadyToStart onward                     |
| `pkg/controller/backup_queue_controller.go`  | Queue management, concurrency, namespace conflict detection               |
| `pkg/controller/restore_controller.go`       | State machine for Restore CRD lifecycle                                   |
| `pkg/controller/schedule_controller.go`      | Cron trigger logic, creates Backup objects                                |
| `pkg/controller/gc_controller.go`            | Expired backup detection and deletion                                     |
| `pkg/controller/backup_sync_controller.go`   | Reads BSL to sync Backup objects into cluster                             |
| `pkg/controller/data_upload_controller.go`   | Data mover pod lifecycle + VGDP concurrency + cancel/finalizer handling   |
| `pkg/controller/data_download_controller.go` | Mirror of data upload for restore path                                    |

## Patterns

### Finalizer-based Cleanup

Restore, DataUpload, DataDownload, and PodVolumeBackup all use 
**finalizers** to ensure resource cleanup before deletion. The controller 
adds a finalizer when it starts processing and removes it only after cleanup 
is complete.

!!! warning "Stuck in Terminating"
    If a controller crashes between adding a finalizer and completing cleanup, 
    the resource gets stuck in `Terminating`. Check for abandoned finalizers 
    with: `kubectl get <resource> -n velero -o jsonpath='{.items[*].metadata.finalizers}'`

### Phase State Machines

All CRDs follow a similar pattern:
`New → InProgress → WaitingForPluginOperations → Finalizing → Completed/Failed`

Partial failure is tracked separately — `PartiallyFailed` and 
`FinalizingPartiallyFailed` carry errors from individual items without 
failing the entire operation.

### Concurrency Control

- **Backup queue**: Configurable concurrent backup limit
- **VGDP counter**: Limits concurrent data movement jobs per node
- **Progress throttle**: Updates throttled to 1s to avoid API server pressure

## Next Up

[Hooks System](hooks.md)
