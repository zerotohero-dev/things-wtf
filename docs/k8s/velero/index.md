---
title: Velero
---

## **Velero**: from zero to active upstream contributor

This guide takes you from the design philosophy of Velero through its internals, 
extension points, codebase layout, and into the practical mechanics of 
contributing upstream.

Before you start, you should be familiar with Kubernetes and the Kubernetes API.

You should also be familiar with Kubernetes Operators and Custom Resource
Definitions (*CRD*s).

Specifically you'd follow this guide much better if you have:

- Kubernetes controller-runtime and CRD conceptual knowledge;
- Go proficiency;
- Familiarity with object storage (*S3/GCS semantics*);
- Basic CSI architecture knowledge.


## How to Best Use This Guide

Work through the sections in order on a first pass. Each section builds on 
the previous. Once you have done the full read, the sections work well as 
standalone references too.

!!! tip "Fastest path to productivity"
    After reading [Architecture](foundations/architecture.md) 
    and [Core CRDs](foundations/crds.md), set up a local `kind` cluster with 
    **Velero** + **MinIO**, then trace a full backup with 
    `--log-level debug`. 

    The code becomes real in a way that reading alone can't achieve.

## Contents

| Section                                                                        | What you get                                                              |
|--------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| **Foundations**                                                                |                                                                           |
| [Overview and Design](foundations/overview.md)                                 | Why Velero is built the way it is. The API-centric, not etcd-centric bet. |
| [Architecture](foundations/architecture.md)                                    | Process topology, controller-runtime reconcilers, plugin gRPC model.      |
| [Core CRDs](foundations/crds.md)                                               | Every CRD field that matters and its lifecycle semantics.                 |
| **Internals**                                                                  |                                                                           |
| [Backup Mechanics](internals/backup.md)                                        | The full backup pipeline, step by step, with object store layout.         |
| [Restore Mechanics](internals/restore.md)                                      | Priority ordering, conflict handling, PV restore paths.                   |
| [Controller Deep Dive](internals/controllers.md)                               | All 19 controllers, state machines, which controller owns which phase.    |
| [Hooks System](internals/hooks.md)                                             | Backup pre/post hooks, restore init container hooks, annotation vs spec.  |
| **Extensions**                                                                 |                                                                           |
| [Plugin System](extensions/plugins.md)                                         | All plugin interfaces in Go, process model, deployment pattern.           |
| [Node Agent and Kopia](extensions/node-agent-kopia.md)                         | File-level volume backup internals, data mover microservice model.        |
| [CSI Snapshots](extensions/csi-snapshots.md)                                   | The recommended volume path, VolumeSnapshotClass gotchas, vSphere CSI.    |
| **Contributing**                                                               |                                                                           |
| [Codebase Tour](contributing/codebase-tour.md)                                 | Package map, key files per subsystem, testing conventions, metrics.       |
| [Contributing Upstream](contributing/upstream.md)                              | Governance, PR conventions, high-value contribution areas.                |

## Next Up

[Overview and Design](foundations/overview.md)