---
title: Overview and Design Philosophy
---

Before touching code, it's important to understand *why* Velero is designed the 
way it is: because its architecture is deeply intentional.

## What Does Velero Do?

Velero serializes Kubernetes API objects (*including CRDs*) and optionally 
snapshots persistent volume data, writing both to an object store. 

Its core design insight is: **Kubernetes state is mostly API objects**. 

If you can faithfully capture and replay the API, you've captured most of the 
cluster.

| Capability    | Description                                                                                                                                                                 |
|---------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Backup**    | Lists matching resources via the API server, serializes them to JSON, uploads to object store (S3, GCS, Azure Blob, custom). Volume data via snapshots or file-level copy.  |
| **Restore**   | Downloads from object store, replays resource creation through the API server, handles ordering and dependency resolution. Namespace and resource remapping is first-class. |
| **Schedule**  | Cron-based backup scheduling via a Schedule CRD. Creates Backup objects on schedule. Supports TTL-based pruning of old backups.                                             |
| **Migration** | Backup from cluster A pointing at BSL X; restore in cluster B pointing at the same BSL. Namespace remapping and storage class remapping handle environment differences.     |

!!! note "BSL = BackupStorageLocation"
    BSL is the CRD that tells Velero where to store backups — which bucket, 
    which plugin, which credentials. See [Core CRDs](crds.md#backupstoragelocation-bsl).

## Design Philosophy

Velero is deliberately **API-centric, not etcd-centric**. It never reaches into 
`etcd` directly. 

This design decision shapes the following features:

- **Works across clusters**: Restores aren't tied to the originating cluster's 
  `etcd` format or version.
- **Controller-pattern**: Everything is a CRD reconciled by a controller. 
  Backup lifecycle is observable and debuggable via `kubectl get backup -o yaml`.
- **Plugin-first**: object storage and volume snapshotting are pure interfaces, 
  not embedded implementations. Velero ships no hard dependency on any cloud 
  provider.
- **Selective, not monolithic**: label selectors, namespace filters, resource 
  inclusion/exclusion. You back up what matters, not everything.

!!! tip "Velero is a Reconciliation Loop to Backup and Restore"
    Velero is a **reconciliation loop over Backup/Restore CRDs**, plus a plugin 
    runtime for storage and volume operations. 

    Everything else is orchestration around those two ideas.

## What Velero is **NOT**

Understanding the boundaries prevents misuse and informs what's worth 
contributing:

- **Not a database backup tool**: it snapshots the K8s representation of a 
  database (*PVC*), not application-consistent DB snapshots. 
  Use hooks to quiesce first.
- **Not a disaster recovery tool for the control plane**: it doesn't back up 
  `etcd`, certificates, or `kubeconfig`. Use `etcd` backups for control plane DR.
- **Not idempotent by default**: restoring into a cluster that already has 
  those resources requires explicit `--existing-resource-policy` flags.
- **Not eventually consistent**: backup is a point-in-time snapshot as seen by 
  the API server. Resources created during backup may or may not be included 
  depending on timing.

## Project Status

- **CNCF Graduated** (*May 2023*): stable project with strong governance.
- Maintained by a small core team; VMware/Broadcom historically the largest 
  contributor, though the project is genuinely vendor-neutral.
- Active migration from [Restic](https://restic.net/) to 
  [**Kopia**](https://kopia.io) as the default file-level backup engine: 
  **Kopia** is now default as of `v1.13`. Restic backups can still be 
  *restored* by setting `spec.uploaderType: restic` on the Restore.
- CSI `VolumeSnapshot` integration is the recommended path for volume backup; 
  legacy cloud-provider snapshotter plugins are in maintenance mode.

## Next Up

[Velero Architecture](architecture.md)
