# Backup Mechanics

The backup pipeline is where most of Velero's complexity lives.

Understanding this path is essential for debugging, performance tuning, 
and writing plugins.

## Backup lifecycle state machine

The full state machine involves **4 controllers** in sequence:

```
                    BackupQueueController
New ──► Queued ──► ReadyToStart
                        │
                   BackupController
                   ReadyToStart ──► InProgress
                                        │
                              BackupOperationsController
                              WaitingForPluginOperations
                              WaitingForPluginOperationsPartiallyFailed
                                        │
                              BackupFinalizerController
                              Finalizing / FinalizingPartiallyFailed
                                        │
                              Completed / PartiallyFailed / Failed
                                        │
                                   ──► Deleting (via DeleteBackupRequest)
```

The `BackupQueueController` enforces concurrency limits and detects 
namespace conflicts (*two backups covering the same namespaces cannot run 
simultaneously*). Once a Backup reaches `ReadyToStart`, the 
`BackupController` takes over and drives execution.

## Step-by-step Backup Execution

### 1. BackupController Picks Up a New Backup

A controller-runtime informer watches for Backup objects reaching 
`ReadyToStart` phase. The controller sets `status.phase = InProgress` and 
`status.startTimestamp`.

In HA deployments, controller-runtime's leader election (*via Kubernetes 
leases*) ensures only one replica runs reconcilers at a time, preventing 
concurrent execution of the same backup.

### 2. Resource Discovery and Collection

Uses the API server's discovery API to enumerate all resource types. For each 
resource type matching the include/exclude filters, lists objects via the 
**dynamic client** (*an untyped Kubernetes client that works with any resource 
type without compiled Go structs — essential for backing up CRDs whose types 
Velero doesn't know at compile time*). 

Discovery is done concurrently with goroutines per resource group.

Key file: `pkg/backup/item_collector.go`

### 3. BackupItemAction Plugins

For each collected item, runs all registered `BackupItemAction` plugins 
whose `AppliesTo()` matches the resource type. These can:

- **Mutate** the item (*e.g. strip sensitive annotations*)
- **Add additional items** to the backup graph (*e.g. the built-in 
  `pod-action` adds the PVC when a Pod is backed up, ensuring PVC/PV 
  pairs are consistent*)
- **Set skip flags** to exclude an item

This is where most custom business logic lives. 
See [Plugin System](../extensions/plugins.md).

### 4. PVC → Volume Backup Decision

For each PVC, Velero decides the volume backup method. **Volume policies** 
(*ConfigMap-based, referenced via `spec.resourcePolicy`*) take highest 
precedence, followed by pod annotations, then defaults:

1. **Volume policy match** (*if configured*): a `ResourcePolicies` ConfigMap 
   can match by storage class, CSI driver, capacity, NFS config, PVC labels, 
   or PVC phase. The first matching rule's action wins: `skip`, `fs-backup`, 
   or `snapshot`.
2. **Skip**: if `snapshotVolumes: false` or if the PVC has the opt-out
   annotation `backup.velero.io/backup-volumes-excludes`
3. **CSI VolumeSnapshot**: if the CSI plugin is enabled and a matching 
   VolumeSnapshotClass exists
4. **Cloud provider snapshot**: if a VolumeSnapshotter plugin is registered
   for the storage class
5. **Kopia file-level copy**: if `defaultVolumesToFsBackup: true` or if the
   PVC has the opt-in annotation `backup.velero.io/backup-volumes`

!!! tip "Volume policies are the modern approach"
    Volume policies replace the annotation-based per-pod opt-in/out model. 
    They're centrally managed, support rich matching conditions, and 
    apply cluster-wide without modifying application manifests.

### 5. Pre-backup hooks

Before serializing a pod's volume data, executes pre-backup hooks 
(*exec into containers*). Used to quiesce databases, flush caches, sync 
filesystems. See [Hooks](hooks.md).

### 6. Volume Snapshot / Data Upload

=== "CSI / Kopia path"
    Creates `DataUpload` CRDs. The `DataUploadController` in node-agent picks 
    these up and runs Kopia to upload data directly from the PVC mount on the 
    node. Velero-server polls `DataUpload.status` for completion.

=== "Cloud snapshot path"
    Calls the `VolumeSnapshotter` plugin synchronously. The plugin calls the 
    cloud provider API and returns a snapshot ID that Velero stores in the 
    backup metadata.

### 7. Post-backup hooks

After volume data is captured, runs post-backup hooks to un-quiesce 
(e.g. `UNLOCK TABLES`). Velero guarantees post hooks run even if pre hooks 
fail (*unless `onError: Fail` caused the backup to abort*).

### 8. Serialization and Upload

All collected, plugin-processed items are serialized to `JSON` and written into 
a tarball (`backup.tar.gz`). A `backup-results.gz` file captures warnings and 
errors per item. Both are streamed to the object store via the ObjectStore 
plugin.

Key file: `pkg/backup/backup.go`

### 9. Metadata Upload

A `velero-backup.json` metadata file is written to the BSL. This is what the 
`BackupSyncController` reads to reconstruct Backup objects in a new cluster 
(*enabling cross-cluster restores without re-creating Backup CRDs manually*).

## Object Store Layout

```
{bucket}/{prefix}/
  backups/
    {backup-name}/
      velero-backup.json                       # Backup CRD spec + status
      {backup-name}.tar.gz                     # All K8s resources (JSON per item)
      {backup-name}-logs.gz                    # Velero server logs during backup
      {backup-name}-results.gz                 # Warnings and errors per item
      {backup-name}-csi-volumesnapshots.json.gz  # CSI snapshot metadata
      {backup-name}-volumesnapshots.json.gz    # Legacy VSL snapshot metadata
  restores/
    {restore-name}/
      restore-{restore-name}-logs.gz
      restore-{restore-name}-results.gz
```

## Tar Archive Structure

```
resources/
  deployments/
    namespaces/
      default/
        my-deployment.json
  persistentvolumeclaims/
    namespaces/
      default/
        my-pvc.json
  persistentvolumes/
    cluster/                    # cluster-scoped resources live here
      pvc-abc123.json
```

## Useful Debug Techniques

```bash
# Watch backup progress
kubectl get backup my-backup -n velero -o yaml -w

# Stream velero server logs during a backup
kubectl logs -n velero deployment/velero -f --since=5m

# Inspect what's in the tar archive
velero backup download my-backup --output /tmp/my-backup.tar.gz
tar -tzf /tmp/my-backup.tar.gz | head -50

# See per-item warnings/errors
velero backup describe my-backup --details
```

!!! info "Performance Note"
    Backup speed is bound by API server list throughput and object store upload 
    bandwidth. For large clusters (*10k+ objects*), the list phase dominates. 

    The `spec.resourceVersion` is set at list time: items added after listing 
    may be missing from the backup.

## Next Up

[Restore Mechanics](restore.md)