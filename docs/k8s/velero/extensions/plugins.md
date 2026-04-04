---
title: Plugin System
---

Velero's plugin system is its most powerful extension point. Understanding the 
interfaces and process model is essential for both implementing plugins and 
contributing to core.

## Plugin types

| Type                        | Version | Purpose                                                                                     |
|-----------------------------|---------|----------------------------------------------------------------------------------------------|
| `ObjectStore`               | v1      | Read/write/list for a storage backend. Every deployment needs one. **External only.**        |
| `VolumeSnapshotter`         | v1      | Cloud-provider-specific volume snapshots. Legacy path. **External only.**                    |
| `BackupItemAction`          | v1, v2  | Runs per-item during backup. Can mutate, skip, or expand the item graph.                     |
| `RestoreItemAction`         | v1, v2  | Runs per-item during restore. Can mutate items before they're applied to the cluster.        |
| `DeleteItemAction`          | v1      | Runs when a backup is deleted. Allows plugins to clean up associated cloud resources.        |
| `ItemBlockAction`           | v1      | Groups related items for atomic processing (*e.g. PVC + its PV*).                            |

### v1 → v2 Evolution

V2 plugin interfaces add **async operation support**, critical for 
long-running operations like CSI data movement:

- `Execute()` returns an `operationID` for long-running work
- `Progress(operationID)` polls operation status
- `Cancel(operationID)` cancels in-flight operations
- RestoreItemAction v2 adds `AreAdditionalItemsReady()` for dependency 
  waiting and `SkipRestore` flag

V1 plugins are **automatically adapted to the V2 interface** — they work 
transparently with empty operation IDs and no async support.

## ObjectStore interface

```go
// pkg/plugin/velero/object_store.go
type ObjectStore interface {
    // Init is called once with the config map from BSL.spec.config
    Init(config map[string]string) error

    // PutObject writes the given body to bucket/key
    PutObject(bucket, key string, body io.Reader) error

    // ObjectExists returns true if bucket/key exists
    ObjectExists(bucket, key string) (bool, error)

    // GetObject returns the body of bucket/key
    GetObject(bucket, key string) (io.ReadCloser, error)

    // ListCommonPrefixes returns all "directories" under prefix/delimiter
    ListCommonPrefixes(bucket, prefix, delimiter string) ([]string, error)

    // ListObjects returns all keys with given prefix
    ListObjects(bucket, prefix string) ([]string, error)

    // DeleteObject deletes the object at bucket/key
    DeleteObject(bucket, key string) error

    // CreateSignedURL returns a pre-signed URL for the object
    CreateSignedURL(bucket, key string, ttl time.Duration) (string, error)
}
```

## BackupItemAction interface

```go
// pkg/plugin/velero/backup_item_action.go
type BackupItemAction interface {
    // AppliesTo returns what resource types this action handles
    AppliesTo() (ResourceSelector, error)

    // Execute is called for each matching item during backup.
    // Returns the (possibly mutated) item and any additional items to back up.
    Execute(item runtime.Unstructured, backup *api.Backup) (
        updatedItem runtime.Unstructured,
        additionalItems []ResourceIdentifier,
        error,
    )
}

type ResourceSelector struct {
    IncludedNamespaces []string
    ExcludedNamespaces []string
    IncludedResources  []string  // "pods", "persistentvolumeclaims"
    ExcludedResources  []string
    LabelSelector      string
}
```

## RestoreItemAction interface

```go
// pkg/plugin/velero/restore_item_action.go
type RestoreItemAction interface {
    AppliesTo() (ResourceSelector, error)

    // Execute is called for each item during restore.
    // Returns the (possibly mutated) item, any additional items to restore,
    // and whether to skip this item entirely.
    Execute(input *RestoreItemActionExecuteInput) (*RestoreItemActionExecuteOutput, error)
}

type RestoreItemActionExecuteInput struct {
    Item           runtime.Unstructured   // item from the backup
    ItemFromBackup runtime.Unstructured   // same item, always unmodified
    Restore        *api.Restore
}

type RestoreItemActionExecuteOutput struct {
    UpdatedItem     runtime.Unstructured
    AdditionalItems []ResourceIdentifier
    SkipRestore     bool
}
```

## Implementing a Plugin

Use [velero-plugin-example](https://github.com/vmware-tanzu/velero-plugin-example) as a scaffold.

```go
// main.go
func main() {
    veleroplugin.NewServer().
        // Register all plugin types your binary implements
        RegisterObjectStore("my.company/my-store", newMyObjectStore).
        RegisterBackupItemAction("my.company/strip-secrets", newStripSecretsAction).
        RegisterRestoreItemAction("my.company/remap-storageclass", newRemapStorageClass).
        Serve()
}

func newMyObjectStore(logger logrus.FieldLogger) (interface{}, error) {
    return &MyObjectStore{logger: logger}, nil
}

// MyObjectStore implements the ObjectStore interface
type MyObjectStore struct {
    logger logrus.FieldLogger
    client *minio.Client
}

func (o *MyObjectStore) Init(config map[string]string) error {
    endpoint := config["endpoint"]
    // ... initialize minio client
    return nil
}
```

## Plugin Deployment Model

Plugins are bundled into the velero pod via an init container pattern. 

The init container copies the plugin binary to a shared `EmptyDir` volume 
mounted at `/plugins`.

```yaml
initContainers:
- name: velero-plugin-for-aws
  image: velero/velero-plugin-for-aws:v1.10.0
  volumeMounts:
  - name: plugins
    mountPath: /target
  command: ["/bin/sh", "-c", "cp /velero-plugin-for-aws /target/"]

volumes:
- name: plugins
  emptyDir: {}

containers:
- name: velero
  volumeMounts:
  - name: plugins
    mountPath: /plugins   # velero scans this directory at startup
```

Velero scans `/plugins` at startup and registers all binaries it finds. Each 
binary is invoked via go-plugin's handshake protocol to discover its 
capabilities.

## Plugin Versioning

Plugin gRPC protocol is versioned. When upgrading Velero, check the 
compatibility matrix in the plugin's README. Breaking changes to plugin 
interfaces are rare but happen across minor versions. Watch for interface 
changes in `pkg/plugin/velero/`.

## Built-In BackupItemActions

Velero ships several built-in BIAs worth knowing:

| Name                        | Applies to               | What it does                                            |
|-----------------------------|--------------------------|---------------------------------------------------------|
| `pod-action`                | `pods`                   | Adds the pod's PVCs (and their PVs) to the backup graph |
| `pvc-action`                | `persistentvolumeclaims` | Adds the bound PV; triggers volume backup decision      |
| `csi-pvc-backupitem-action` | `persistentvolumeclaims` | Creates VolumeSnapshot for CSI-backed PVCs              |
| `service-account-action`    | `serviceaccounts`        | Includes secrets referenced by the SA                   |
| `role-bindings-action`      | `rolebindings`           | Includes referenced Roles/ClusterRoles                  |

## Built-in RestoreItemActions

| Name                                       | Applies to               | What it does                                                                               |
|--------------------------------------------|--------------------------|--------------------------------------------------------------------------------------------|
| `job-action`                               | `jobs`                   | Removes `spec.selector` and `spec.template.labels` so the job controller re-generates them |
| `service-action`                           | `services`               | Strips `spec.clusterIP`, `spec.clusterIPs`, `spec.nodePort`                                |
| `serviceaccount-action`                    | `serviceaccounts`        | Strips auto-generated secret token references                                              |
| `csi-volumesnapshot-restore-action`        | `volumesnapshots`        | Handles VolumeSnapshot object restoration binding                                          |
| `csi-volumesnapshotcontent-restore-action` | `volumesnapshotcontents` | Handles VolumeSnapshotContent with the original snapshot handle                            |

## Next Up

[Node Agent and Kopia](node-agent-kopia.md)