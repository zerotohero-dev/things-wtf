# Core CRDs

Velero's entire surface area is expressed as CRDs. These are the objects you 
need to know deeply: both spec fields and status lifecycle.

## BackupStorageLocation (*BSL*)

The **BSL** is the most critical config object. It tells Velero where to store 
backups and which plugin to use. Multiple BSLs are supported; 
one is marked `default: true`.

| Field                       | Type                       | Description                                                                                              |
|-----------------------------|----------------------------|----------------------------------------------------------------------------------------------------------|
| `spec.provider`             | `string`                   | Plugin identifier, e.g. `velero.io/aws`. Must match a registered ObjectStore plugin.                     |
| `spec.objectStorage.bucket` | `string`                   | Bucket/container name in the object store.                                                               |
| `spec.objectStorage.prefix` | `string`                   | Optional prefix for all objects. Enables multiple clusters sharing one bucket.                           |
| `spec.config`               | `map[string]string`        | Provider-specific config (*region, s3Url, checksumAlgorithm, etc.*).                                     |
| `spec.credential`           | `SecretKeySelector`        | Secret containing credentials. If absent, uses the plugin's default credential chain.                    |
| `spec.accessMode`           | `ReadWrite \| ReadOnly`    | `ReadOnly` for a restore-only BSL (*e.g. DR cluster pointing at a backup source cluster's bucket*).      |
| `spec.validationFrequency`  | `duration`                 | How often BSLController validates availability. Defaults to `1m`.                                        |
| `status.phase`              | `Available \| Unavailable` | BSLController writes this after probing the object store. Backups only proceed against `Available` BSLs. |

```yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: velero.io/aws
  objectStorage:
    bucket: my-velero-backups
    prefix: cluster-prod
  config:
    region: us-west-2
    checksumAlgorithm: ""
  credential:
    name: cloud-credentials
    key: cloud
  default: true
  accessMode: ReadWrite
  validationFrequency: 1m
```

## Backup

The top-level object that describes what to back up. Created by CLI, `Schedule`, 
or directly via `kubectl`.

| Field                           | Type              | Description                                                                                  |
|---------------------------------|-------------------|----------------------------------------------------------------------------------------------|
| `spec.includedNamespaces`       | `[]string`        | Namespaces to include. Wildcard `*` = all (default).                                         |
| `spec.excludedNamespaces`       | `[]string`        | Always exclude these, even if included above.                                                |
| `spec.includedResources`        | `[]string`        | Resource types to include (*e.g. `deployments`, `persistentvolumeclaims`*). Default: all.    |
| `spec.excludedResources`        | `[]string`        | Always skip these. Velero has a built-in excludeList for ephemeral objects (*Events, etc.*). |
| `spec.labelSelector`            | `LabelSelector`   | Only include resources matching this selector.                                               |
| `spec.orLabelSelectors`         | `[]LabelSelector` | Union of label selectors. Added in v1.10 to address the "must match ALL labels" limitation.  |
| `spec.snapshotVolumes`          | `*bool`           | Enable/disable cloud provider volume snapshotting. Set to `false` to skip volume data.       |
| `spec.ttl`                      | `duration`        | After this duration, GCController will delete the backup. Default `720h` (30 days).          |
| `spec.storageLocation`          | `string`          | Name of the BSL to use. Defaults to BSL with `default: true`.                                |
| `spec.hooks`                    | `BackupHooks`     | Pre/post backup hooks on pods. See [Hooks](../internals/hooks.md).                           |
| `spec.defaultVolumesToFsBackup` | `bool`            | If true, all PVCs get Kopia file-level backup in addition to (*or instead of*) snapshots.    |
| `status.phase`                  | `enum`            | `New → InProgress → Completed \| PartiallyFailed \| Failed \| Deleting`                      |
| `status.startTimestamp`         | `time`            | Used by TTL calculation. Expiration = `startTimestamp + TTL`.                                |

### Backup Lifecycle

```
New ──► InProgress ──► Completed
                   └──► PartiallyFailed
                   └──► Failed
                           └──► Deleting  (via DeleteBackupRequest)
```

## Restore

Restores are **immutable after creation**. The RestoreController reconciles 
them **exactly once** to completion.

| Field                                          | Type                | Description                                                                                  |
|------------------------------------------------|---------------------|----------------------------------------------------------------------------------------------|
| `spec.backupName`                              | `string`            | **Required.** Name of the Backup object to restore from.                                     |
| `spec.namespaceMapping`                        | `map[string]string` | Remap namespace names during restore. Essential for migration scenarios.                     |
| `spec.includedResources` / `excludedResources` | `[]string`          | Fine-grained resource filtering, independent of what was backed up.                          |
| `spec.restorePVs`                              | `*bool`             | Whether to restore PV data (via snapshot or file copy).                                      |
| `spec.existingResourcePolicy`                  | `none,update`       | `none` (default) = skip existing resources. `update` = patch existing resources from backup. |
| `spec.hooks`                                   | `RestoreHooks`      | Init container hooks executed during pod restore. See [Hooks](../internals/hooks.md).        |

## VolumeSnapshotLocation (VSL)

VSL configures a cloud provider's volume snapshot API. Less critical since the 
push toward CSI snapshots (*see [CSI Snapshots](../extensions/csi-snapshots.md)*), 
but still required for legacy cloud provider snapshot plugins.

| Field           | Type                | Description                                                 |
|-----------------|---------------------|-------------------------------------------------------------|
| `spec.provider` | `string`            | Plugin identifier for the VolumeSnapshotter implementation. |
| `spec.config`   | `map[string]string` | Provider-specific config (region, apiTimeout, etc.).        |

## Schedule

| Field                             | Type         | Description                                                          |
|-----------------------------------|--------------|----------------------------------------------------------------------|
| `spec.schedule`                   | `string`     | Standard cron expression. Also supports `@every 6h` shorthand.       |
| `spec.template`                   | `BackupSpec` | Backup spec to instantiate on each tick. All Backup fields apply.    |
| `spec.useOwnerReferencesInBackup` | `bool`       | If true, created Backups are owned by the Schedule and GC'd with it. |
| `status.lastBackup`               | `time`       | When the last Backup was created. Used to compute the next trigger.  |

## DeleteBackupRequest

Creating this object triggers the `BackupDeletionController` to delete both the 
object store artifacts **and** the Backup CRD. 

**Do not delete the Backup CRD directly**: 
the object store artifacts will be orphaned.

!!! danger "Operational Rule"
    Always use `velero backup delete <name>` 
    (*or create a DeleteBackupRequest CRD*). 

    **Never** `kubectl delete backup <name>`.

```yaml
apiVersion: velero.io/v1
kind: DeleteBackupRequest
metadata:
  name: delete-my-backup
  namespace: velero
spec:
  backupName: my-backup
```

## BackupRepository

Tracks the lifecycle of a Kopia (*or legacy Restic*) repository per 
`{namespace, BSL, repositoryType}` triple. Created automatically when the 
first volume backup targets a given BSL.

| Field                    | Type     | Description                                                       |
|--------------------------|----------|-------------------------------------------------------------------|
| `spec.volumeNamespace`   | `string` | Namespace of the volumes this repo serves.                        |
| `spec.backupStorageLocation` | `string` | BSL where repository data is stored.                          |
| `spec.repositoryType`    | `string` | `kopia` or `restic`.                                              |
| `spec.maintenanceFrequency` | `duration` | How often to run repository maintenance. Default `7d`.        |
| `status.phase`           | `enum`   | `New → Ready → NotReady`                                          |
| `status.lastMaintenanceTime` | `time` | When maintenance last ran.                                      |

## DataUpload (*v2alpha1*)

Protocol CRD between CSI backup actions and data mover controllers. Created 
by the `PVCBackupItemAction` during backup; reconciled by 
`DataUploadController`.

| Field                        | Type       | Description                                                                          |
|------------------------------|------------|--------------------------------------------------------------------------------------|
| `spec.snapshotType`          | `string`   | `CSI` (current) or `Restic` (legacy). Determines which uploader is used.             |
| `spec.sourceNamespace`       | `string`   | Namespace of the PVC being backed up.                                                |
| `spec.sourcePVC`             | `string`   | Name of the PVC.                                                                     |
| `spec.backupStorageLocation` | `string`   | Which BSL to write Kopia repository data to.                                         |
| `spec.dataMover`             | `string`   | Pluggable data mover identifier. Default `"velero"` → Kopia.                         |
| `spec.operationTimeout`      | `duration` | How long before failing the upload. Tune for large PVCs.                             |
| `spec.cancel`                | `bool`     | Set to `true` to cancel an in-progress upload.                                       |
| `status.phase`               | `enum`     | `New → Accepted → Prepared → InProgress → Completed/Failed/Canceled`                 |
| `status.snapshotID`          | `string`   | Kopia snapshot ID on success. Used by DataDownload to restore.                       |
| `status.node`                | `string`   | Node where the data mover pod ran.                                                   |
| `status.progress`            | `Progress` | `BytesDone / TotalBytes`: live progress from the Kopia upload stream.                |

## DataDownload (*v2alpha1*)

Mirror of DataUpload for the restore path. Created by CSI restore actions; 
reconciled by `DataDownloadController`.

| Field                  | Type       | Description                                                   |
|------------------------|------------|---------------------------------------------------------------|
| `spec.targetVolume`    | `object`   | Target PVC, PV, and namespace for restored data.              |
| `spec.snapshotID`      | `string`   | Kopia snapshot ID to restore from.                            |
| `spec.dataMover`       | `string`   | Pluggable data mover identifier.                              |
| `spec.operationTimeout`| `duration` | Timeout for the download operation.                           |
| `status.phase`         | `enum`     | Mirrors DataUpload phases.                                    |
| `status.node`          | `string`   | Node where the restore mover pod ran.                         |

!!! warning "Alpha API"
    DataUpload and DataDownload are `v2alpha1` — field changes may occur 
    between minor Velero versions. Existing CRs in clusters may need manual 
    cleanup after upgrades.

## CRD Relationship Map

```
Schedule ---creates--> Backup
                         |
                         ├── references BackupStorageLocation
                         ├── references VolumeSnapshotLocation
                         ├── triggers PodVolumeBackup (one per volume, legacy)
                         ├── triggers DataUpload (one per volume, CSI path)
                         └── has DownloadRequest (logs, contents)

Restore ---references--> Backup (or Schedule for latest)
    |
    ├── triggers PodVolumeRestore (one per volume, legacy)
    └── triggers DataDownload (one per volume, CSI path)

BackupRepository ---references--> BackupStorageLocation
    (used by PodVolumeBackup/Restore and DataUpload/Download)

DeleteBackupRequest ---targets--> Backup
```

## Next Up

[Backup Mechanics](../internals/backup.md)