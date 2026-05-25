# Workload Resources

## Overview

| Resource | Use case | Managed by |
|---|---|---|
| `Deployment` | Stateless apps | deployment controller → ReplicaSet controller |
| `ReplicaSet` | Pod replication primitive | replicaset controller |
| `StatefulSet` | Stateful apps (DBs, queues) | statefulset controller |
| `DaemonSet` | One pod per node (agents) | daemonset controller |
| `Job` | Batch / finite work | job controller |
| `CronJob` | Scheduled jobs | cronjob controller → Job |

## Deployment

Manages rolling updates via ReplicaSet churn.

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # extra pods above desired during rollout
      maxUnavailable: 0    # pods allowed to be unavailable during rollout
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 10
```

### Rollout internals

1. Deployment controller computes a hash of `spec.template` and stamps it as `pod-template-hash` label
2. Creates a new ReplicaSet with the new hash; scales it up incrementally
3. Scales down the old ReplicaSet incrementally, respecting `maxSurge` + `maxUnavailable`
4. On completion, old RS is left at 0 replicas (for rollback history)

```
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=2
kubectl rollout pause deployment/myapp   # freeze mid-rollout for canary inspection
kubectl rollout resume deployment/myapp
```

`progressDeadlineSeconds` triggers a `Progressing=False` condition if no RS scaling progress is made within the window. Does not auto-rollback — that requires external tooling (Argo Rollouts, Flagger).

### Revision history

Old ReplicaSets are kept up to `revisionHistoryLimit` (default 10). Each RS carries the full pod template in its spec — this is what rollback restores. Trim `revisionHistoryLimit` to reduce object count in busy clusters.

## ReplicaSet

Ensures exactly N pod replicas matching a label selector are running. Rarely used directly. Key behavior: **adoption** — if pods matching the RS's selector exist but have no ownerReference, the RS adopts them (and may immediately delete excess ones to reach desired count).

!!! warning
    Never change a ReplicaSet's `selector` — it's immutable. Create a new RS (via Deployment rollout) instead.

## StatefulSet

Provides stable identity for pods: ordered names (`pod-0`, `pod-1`, ...), stable DNS, and per-pod PVCs.

```yaml
spec:
  serviceName: myapp-headless        # required: headless service for DNS
  replicas: 3
  podManagementPolicy: OrderedReady  # or Parallel
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0                   # only update pods with ordinal >= partition (canary)
  volumeClaimTemplates:
  - metadata: {name: data}
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: fast
      resources:
        requests: {storage: 10Gi}
```

### Stable DNS

With a headless service (`clusterIP: None`) named `myapp-headless` in namespace `ns`:

```
pod-0.myapp-headless.ns.svc.cluster.local  →  pod-0's IP
pod-1.myapp-headless.ns.svc.cluster.local  →  pod-1's IP
```

This is what allows distributed systems (etcd, Kafka, Zookeeper) to find each other by stable identity.

### PVC lifecycle

PVCs from `volumeClaimTemplates` are named `<template-name>-<pod-name>`:

```
data-myapp-0
data-myapp-1
data-myapp-2
```

**PVCs are NOT deleted when the StatefulSet is deleted or scaled down.** This is intentional — data preservation. Clean up manually:

```bash
kubectl delete pvc -l app=myapp
```

## DaemonSet

Ensures one pod runs on every node (or every node matching a `nodeSelector`/affinity). New nodes joining the cluster automatically get the pod.

Common uses: CNI plugins, log collectors (Fluentd, Vector), monitoring agents (node-exporter, Datadog), security agents, CSI node drivers.

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1     # or percentage
  template:
    spec:
      tolerations:
      - operator: Exists    # tolerate all taints — run even on control-plane nodes
```

## Job

Runs pods until a specified number of successful completions.

```yaml
spec:
  completions: 10        # total successful completions needed
  parallelism: 3         # run up to 3 pods concurrently
  backoffLimit: 4        # pod failures before Job fails
  backoffLimitPerIndex: 1                  # per-index backoff (indexed jobs, 1.29+)
  completionMode: Indexed                  # gives each pod JOB_COMPLETION_INDEX env var
  ttlSecondsAfterFinished: 3600            # auto-cleanup after completion
  podFailurePolicy:                        # (1.28 GA) fine-grained failure handling
    rules:
    - action: Ignore
      onExitCodes: {containerName: main, operator: In, values: [42]}
    - action: FailJob
      onPodConditions: [{type: DisruptionTarget}]
```

Indexed jobs (`completionMode: Indexed`) are the standard pattern for parallel batch work — each pod gets a unique index and processes a subset of the input.

## CronJob

```yaml
spec:
  schedule: "0 2 * * *"          # standard cron syntax, UTC
  timeZone: "America/Los_Angeles" # (1.27 GA)
  concurrencyPolicy: Forbid       # Allow | Forbid | Replace
  startingDeadlineSeconds: 300    # how late a missed run can start
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec: ...
```

`concurrencyPolicy: Forbid` — if the previous run is still active when the next is scheduled, skip. `Replace` — cancel the previous run and start fresh. `Allow` — run concurrently.

!!! note
    CronJob timing is approximate — the controller checks every 10 seconds. Don't rely on sub-minute precision. For strict scheduling, use an external scheduler (Argo Workflows, Airflow) that submits Jobs to Kubernetes.
