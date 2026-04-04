---
title: Codebase Tour
---

This section covers the places to look when you are debugging, adding features, 
or reviewing PRs. 

The Velero codebase is well-structured but has some non-obvious conventions.

## Repository layout

```
velero/
  cmd/
    velero/                   # main() — CLI + server command dispatch
  pkg/
    apis/velero/v1/           # CRD types (Backup, Restore, BSL, etc.)
    backup/                   # Core backup logic — item collector, tar writer
    restore/                  # Core restore logic — item restorer, priority ordering
    controller/               # All reconcilers (controller-runtime)
    plugin/                   # Plugin framework: interfaces, gRPC impl, client mgmt
    plugin/velero/            # Public plugin interfaces (import in your plugin)
    plugin/framework/         # go-plugin server/client plumbing, gRPC proto impl
    plugin/clientmgmt/        # Plugin process lifecycle management
    datamover/                # Data mover microservices (run inside mover pods)
    datapath/                 # Async backup/restore abstraction (FileSystemBR)
    exposer/                  # Volume exposure strategies (CSI snapshot, pod volume)
    podvolume/                # Legacy pod-volume backup/restore (node-agent based)
    uploader/                 # Kopia uploader interface + implementation
    repository/               # Kopia repository management (init, connect, maintain)
    persistence/              # Object store operations for backup metadata
    client/                   # Velero client factory, kubebuilder client setup
    discovery/                # API server resource discovery + grouping
    archive/                  # Tar archive reading/writing
    nodeagent/                # Node-agent DaemonSet interaction
    install/                  # Installation resource generation
    features/                 # Feature flag system
    constant/                 # Shared constants (controller names, plugin names)
    util/                     # Shared utilities (kube, csi, logging, etc.)
    metrics/                  # Prometheus metrics (~40 metrics)
    builder/                  # Test object builders (fluent constructors)
    test/                     # Shared test helpers and mocks
  internal/
    hook/                     # Pre/post hook execution on pods
    resourcemodifiers/        # JSON/merge/strategic patches during restore
    resourcepolicies/         # Volume policy engine (skip/fs-backup/snapshot)
    volume/                   # Volume metadata and snapshot location utilities
    volumehelper/             # Volume decision helpers
    credentials/              # Credential loading from files and K8s secrets
    delete/                   # Backup deletion + CSI cleanup
    storage/                  # BSL validation helpers
  design/                     # Design documents for major features
  changelogs/                 # Per-PR changelog fragments
  hack/                       # Build scripts, code gen, e2e setup
  config/                     # CRD manifests (generated)
```

## Key files by subsystem

### Backup pipeline

| File                           | What's in it                                                                             |
|--------------------------------|------------------------------------------------------------------------------------------|
| `pkg/backup/item_collector.go` | Resource discovery and collection. Start here to understand what gets backed up and why. |
| `pkg/backup/backup.go`         | Top-level backup orchestrator: calls item collector, runs BIAs, writes tar.              |
| `pkg/backup/item_backupper.go` | Per-item processing: runs BackupItemActions, handles volume decisions.                   |
| `pkg/backup/pod_action.go`     | Built-in BIA: when a pod is backed up, adds its PVCs.                                    |
| `pkg/backup/pvc_action.go`     | Built-in BIA: adds the PV and triggers volume backup decision.                           |

### Restore pipeline

| File                            | What's in it                                                               |
|---------------------------------|----------------------------------------------------------------------------|
| `pkg/restore/restore.go`        | Restore orchestrator: priority ordering, item restorer calls, PV handling. |
| `pkg/restore/item_restorer.go`  | Per-item processing: runs RestoreItemActions, handles conflict policy.     |
| `pkg/restore/service_action.go` | Built-in RIA: strips clusterIP from Services.                              |

### Controllers

| File                                         | What's in it                                                              |
|----------------------------------------------|---------------------------------------------------------------------------|
| `pkg/controller/backup_controller.go`        | State machine for Backup CRD lifecycle. Entry point for BackupController. |
| `pkg/controller/restore_controller.go`       | State machine for Restore CRD lifecycle.                                  |
| `pkg/controller/schedule_controller.go`      | Cron trigger logic, creates Backup objects.                               |
| `pkg/controller/gc_controller.go`            | Expired backup detection and deletion.                                    |
| `pkg/controller/backup_sync_controller.go`   | Reads BSL to sync Backup objects into cluster.                            |
| `pkg/controller/data_upload_controller.go`   | node-agent side: reconciles DataUpload CRDs.                              |
| `pkg/controller/data_download_controller.go` | node-agent side: reconciles DataDownload CRDs.                            |

### Plugin system

| File                     | What's in it                                                                                        |
|--------------------------|-----------------------------------------------------------------------------------------------------|
| `pkg/plugin/velero/`     | All public plugin interfaces. Read these before writing a plugin.                                   |
| `pkg/plugin/framework/`  | gRPC wiring between velero and plugin processes. Useful when debugging plugin communication issues. |
| `pkg/plugin/clientmgmt/` | Plugin process lifecycle (start, stop, restart on crash).                                           |

### Volume / Kopia

| File                         | What's in it                                                                   |
|------------------------------|--------------------------------------------------------------------------------|
| `pkg/podvolume/backupper.go` | Kopia/Restic PVC backup orchestration: creates DataUpload CRDs, tracks status. |
| `pkg/podvolume/restorer.go`  | PVC restore orchestration: creates DataDownload CRDs.                          |
| `pkg/uploader/kopia/`        | Kopia library integration: snapshot creation, progress tracking.               |
| `pkg/repository/`            | Kopia repository management (*init, connect, maintenance*).                    |

### CRD types

| File                             | What's in it                                                   |
|----------------------------------|----------------------------------------------------------------|
| `pkg/apis/velero/v1/types.go`    | All CRD type definitions. Source of truth for field semantics. |
| `pkg/apis/velero/v1/register.go` | Scheme registration: add new CRDs here.                        |

## Testing conventions

### Unit tests

Live adjacent to the code (`backup_test.go` next to `backup.go`). Use `testify/assert` and `testify/require`.

```go
func TestBackupWithHooks(t *testing.T) {
    require.NoError(t, err)
    assert.Equal(t, velerov1api.BackupPhaseCompleted, backup.Status.Phase)
}
```

### Builder pattern for test objects

```go
// Use pkg/builder/ — don't construct literal structs in tests
backup := builder.ForBackup(velerov1api.DefaultNamespace, "test-backup").
    IncludedNamespaces("app", "db").
    StorageLocation("default").
    TTL(metav1.Duration{Duration: 72 * time.Hour}).
    Result()

restore := builder.ForRestore(velerov1api.DefaultNamespace, "test-restore").
    Backup("test-backup").
    Result()
```

### E2E tests

Located in `pkg/test/e2e/`. Use [ginkgo](https://onsi.github.io/ginkgo/). Require a running cluster.

```bash
# Run E2E tests
make test-e2e

# Run a specific E2E test
cd pkg/test/e2e && go test ./... -run TestE2E/backup_restore_with_csi
```

### Fake client

Controller tests use controller-runtime's `envtest` or a fake client:

```go
fakeClient := fake.NewClientBuilder().
    WithScheme(scheme).
    WithObjects(backup).
    Build()
```

## Generated Code

CRD deepcopy functions and CRD manifests are generated. Do not edit them manually:

```bash
make generate            # Runs controller-gen for deepcopy, CRD manifests
make verify-generate     # CI check that generated code is up-to-date
make update-generated-crd-code  # Alias used in some PR workflows
```

## Prometheus Metrics

All metrics are defined in `pkg/metrics/metrics.go`. The velero server exposes `:8085/metrics` by default.

| Metric                                    | Type      | Description                                                |
|-------------------------------------------|-----------|------------------------------------------------------------|
| `velero_backup_total`                     | Counter   | Total backups, by schedule and phase                       |
| `velero_backup_duration_seconds`          | Histogram | Backup duration distribution                               |
| `velero_backup_last_successful_timestamp` | Gauge     | Last successful backup per BSL/schedule — use for alerting |
| `velero_restore_total`                    | Counter   | Total restores by phase                                    |
| `velero_volume_snapshot_success_total`    | Counter   | Successful volume snapshots                                |
| `velero_volume_snapshot_failure_total`    | Counter   | Failed volume snapshots                                    |
| `velero_backup_items_total`               | Gauge     | Items in last backup, by resource type                     |

```yaml
# Example alert: no successful backup in 25 hours
- alert: VeleroBackupMissed
  expr: time() - velero_backup_last_successful_timestamp > 90000
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Velero backup missed"
```

## Build and Run Locally

```bash
# Prerequisites: Go 1.21+, Docker, kind
git clone https://github.com/vmware-tanzu/velero
cd velero

make build         # Build velero binary to _output/bin/
make test          # Unit tests
make lint          # golangci-lint (matches CI config)
make container     # Build velero container image

# Run velero server locally (fast iteration without building containers)
./_output/bin/linux/amd64/velero server \
  --log-level debug \
  --kubeconfig ~/.kube/config
```

## Design Documents

Before contributing to any area, read the relevant design doc in `design/`:

- `design/plugin-refactoring.md`: plugin v2 architecture rationale
- `design/pvc-backup-restore.md`: the PVC/volume backup decision tree
- `design/csi-volumesnapshots.md`: CSI integration design
- `design/kopia-integration.md`: why Kopia was chosen over Restic
- `design/item-snapshotter.md`: ItemSnapshotter v2alpha interface
