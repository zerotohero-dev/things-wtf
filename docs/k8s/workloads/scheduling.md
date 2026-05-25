# Scheduling & QoS

## Scheduling primitives

### nodeSelector

Simplest form. Hard requirement — pod stays `Pending` if no node matches.

```yaml
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
    topology.kubernetes.io/zone: us-west-2a
```

### nodeAffinity

More expressive node selection. Two modes:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:    # hard
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/arch
            operator: In
            values: [amd64, arm64]
      preferredDuringSchedulingIgnoredDuringExecution:   # soft
      - weight: 80
        preference:
          matchExpressions:
          - key: node-type
            operator: In
            values: [high-mem]
```

"IgnoredDuringExecution" means: if a node's labels change after a pod is scheduled, the pod is not evicted. `RequiredDuringExecution` (not yet GA) would evict in that case.

### podAffinity & podAntiAffinity

Co-locate or spread pods relative to other pods, scoped by a topology key.

```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels: {app: myapp}
        topologyKey: kubernetes.io/hostname    # one pod per node
    podAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels: {app: cache}
          topologyKey: topology.kubernetes.io/zone   # prefer same zone as cache
```

!!! warning "Hard anti-affinity can block scheduling"
    If every node already runs one replica of your app and `required` anti-affinity prevents co-location, a scale-up will leave new pods `Pending` indefinitely. Use `preferred` anti-affinity for HA spread unless you can guarantee enough nodes.

### topologySpreadConstraints

The preferred way to spread pods across topology domains (zones, nodes, racks).

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1                                    # max allowed imbalance
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule              # or ScheduleAnyway
    labelSelector:
      matchLabels: {app: myapp}
    matchLabelKeys: [pod-template-hash]            # (1.29 GA) per-rollout skew
    minDomains: 3                                  # require at least 3 zones
  - maxSkew: 2
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels: {app: myapp}
```

`matchLabelKeys` is important for Deployments during rollout — without it, pods from the old RS and new RS are counted together, breaking spread guarantees mid-rollout.

### Taints & tolerations

Taints repel pods from nodes. Pods must explicitly tolerate a taint to schedule on a tainted node.

```yaml
# Add a taint to a node:
kubectl taint nodes gpu-node-1 dedicated=gpu:NoSchedule

# Tolerate it in the pod:
spec:
  tolerations:
  - key: dedicated
    operator: Equal
    value: gpu
    effect: NoSchedule
  - key: node.kubernetes.io/not-ready   # built-in: tolerate brief node issues
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 60               # evict after 60s of not-ready
```

Taint effects:

| Effect | Behavior |
|---|---|
| `NoSchedule` | Won't schedule new pods without toleration. Existing pods unaffected. |
| `PreferNoSchedule` | Avoid scheduling without toleration; not guaranteed. |
| `NoExecute` | Won't schedule and evicts existing pods without toleration (optionally after `tolerationSeconds`). |

System taints added automatically: `node.kubernetes.io/not-ready`, `node.kubernetes.io/unreachable`, `node.kubernetes.io/memory-pressure`, `node.kubernetes.io/disk-pressure`, `node.kubernetes.io/pid-pressure`, `node.kubernetes.io/unschedulable`.

## QoS classes

Derived automatically from requests/limits — you cannot set QoS directly.

| Class | Condition | Eviction order |
|---|---|---|
| `Guaranteed` | Every container has requests == limits for both CPU and memory | Last evicted |
| `Burstable` | At least one container has requests/limits, but not Guaranteed | Middle |
| `BestEffort` | No requests or limits on any container | First evicted |

The kubelet uses QoS class to determine eviction order under memory pressure. The OOM killer also uses it (Guaranteed pods get OOM score -997, others get scores proportional to their usage vs requests).

### CPU vs memory limits

!!! note "CPU limits cause throttling; memory limits cause kills"
    **CPU**: limits are enforced via cgroup `cpu.cfs_quota_us`. A container exceeding its CPU limit is *throttled* (CFS bandwidth throttling) — it can't use more CPU, but it's never killed. This causes latency spikes and is often worse than no CPU limit at all.

    **Memory**: limits are enforced via cgroup `memory.limit_in_bytes`. A container exceeding its memory limit is *OOMKilled* — immediate process death.

    Common production pattern for latency-sensitive services:
    - Set memory requests == memory limits (Guaranteed QoS for memory)
    - Set CPU requests (for scheduling/QoS)
    - **Omit CPU limits** (let the process burst freely on idle cores)

## PriorityClass

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority   # or Never
description: "For latency-sensitive production services"
```

Built-in system priorities:

| Name | Value |
|---|---|
| `system-node-critical` | 2000001000 |
| `system-cluster-critical` | 2000000000 |

When the scheduler can't place a high-priority pod, it evicts lower-priority pods to make room (preemption). Evicted pods go back to `Pending` and are rescheduled. Use `preemptionPolicy: Never` for priority-based queue ordering without eviction.

## PodDisruptionBudget

Limits voluntary disruptions (node drains, rolling updates, cluster autoscaler scale-downs).

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  selector:
    matchLabels: {app: myapp}
  minAvailable: 2        # or maxUnavailable: 1 (not both)
  unhealthyPodEvictionPolicy: AlwaysAllow   # (1.27 GA) evict unhealthy pods even if PDB is tight
```

The eviction API (used by `kubectl drain`) checks PDBs before evicting pods. If evicting a pod would violate the PDB, the eviction is denied and drain waits.

!!! note "PDB only covers voluntary disruptions"
    Node failures (involuntary disruptions) bypass PDBs. For HA, use pod anti-affinity across zones, not just PDBs.

## Vertical Pod Autoscaler (VPA)

Recommends or automatically sets resource requests based on observed usage. Three modes:

- `Off` — recommends only (no changes)
- `Initial` — sets requests at pod creation only
- `Auto` — updates running pods (evicts and recreates)

VPA and HPA should not both manage CPU/memory on the same Deployment. Use VPA for CPU/memory sizing, HPA for replica count, or use VPA in `Off` mode for recommendations only.

## Horizontal Pod Autoscaler (HPA)

Scales replica count based on metrics.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: myapp}
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: {type: Utilization, averageUtilization: 70}
  - type: External
    external:
      metric:
        name: queue_depth
        selector: {matchLabels: {queue: orders}}
      target: {type: AverageValue, averageValue: "30"}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # wait before scaling down
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleUp:
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```
