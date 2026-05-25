# SIGs — Special Interest Groups

Kubernetes is governed by SIGs (Special Interest Groups), each owning a domain of the project. SIGs run weekly or bi-weekly public meetings (recorded and posted to YouTube), maintain their own roadmaps, and are the primary path for contributing to Kubernetes.

Community structure:

```
Steering Committee   ← overall project governance
    ├── SIGs         ← domain ownership (code, docs, design)
    ├── Working Groups (WGs)  ← cross-SIG efforts with a defined end state
    └── Committees   ← specific responsibilities (Security, Code of Conduct)
```

## SIG directory

### SIG API Machinery

**Owns**: `kube-apiserver`, `kube-aggregator`, `apiextensions-apiserver` (CRDs), `client-go`, `apimachinery`, `controller-runtime` (co-owned with SIG Apps), admission webhooks, API versioning policy, Server-Side Apply, watches, informers, conversion, OpenAPI generation.

Key repos: `kubernetes/kubernetes` (staging/src/k8s.io/\*), `kubernetes/client-go`, `kubernetes/apimachinery`, `kubernetes-sigs/controller-runtime`

If you write controllers, operators, or CRDs — most of your foundational questions are answered by SIG API Machinery.

---

### SIG Apps

**Owns**: `Deployment`, `StatefulSet`, `DaemonSet`, `ReplicaSet`, `Job`, `CronJob`, workload API evolution, application lifecycle, `controller-runtime` (co-owned).

Key repos: `kubernetes/kubernetes` (pkg/controller/\*), `kubernetes-sigs/kubebuilder`, `kubernetes-sigs/controller-runtime`

---

### SIG Auth

**Owns**: Authentication (x509, OIDC, bootstrap tokens, service account tokens, webhook), Authorization (RBAC, Node, Webhook, ABAC), `PodSecurity` admission (successor to PSP), audit logging, `CertificateSigningRequest`, bound service account tokens, SPIFFE integration direction.

Key repos: `kubernetes/kubernetes` (plugin/pkg/auth/\*), `kubernetes-sigs/secrets-store-csi-driver`

---

### SIG CLI

**Owns**: `kubectl`, `kustomize` integration, kubectl plugin mechanism (`kubectl-*` binaries), `kubectl` alpha/beta commands, UX for CLI tooling.

Key repos: `kubernetes/kubectl`, `kubernetes-sigs/kustomize`, `kubernetes/cli-runtime`

---

### SIG Cloud Provider

**Owns**: cloud-controller-manager interface, CCM framework, out-of-tree cloud provider implementations (AWS, GCP, Azure, etc.), cloud provider feature parity requirements.

Key repos: `kubernetes/cloud-provider`, `kubernetes/cloud-provider-aws`, `kubernetes/cloud-provider-gcp`

---

### SIG Cluster Lifecycle

**Owns**: `kubeadm`, cluster bootstrap, upgrade tooling, `kubetest2`, etcd cluster management, control plane HA, cluster API (co-owned with SIG API Machinery).

Key repos: `kubernetes/kubeadm`, `kubernetes-sigs/cluster-api`, `kubernetes-sigs/kubetest2`

---

### SIG Instrumentation

**Owns**: Prometheus metrics exposition across all components, structured logging migration, distributed tracing (OpenTelemetry integration), Events API, log verbosity policy, `klog`.

Key repos: `kubernetes/kubernetes` (staging/src/k8s.io/component-base/metrics/\*), `kubernetes-sigs/instrumentation-tools`

---

### SIG Multicluster

**Owns**: Multi-cluster API standards, `ClusterSet`, service export/import (`MultiClusterService` API), cross-cluster workload placement, namespace sameness.

Key repos: `kubernetes-sigs/mcs-api`, `kubernetes-sigs/work-api`, `kubernetes-sigs/about-api`

---

### SIG Network

**Owns**: `Service`, `Endpoints`, `EndpointSlice`, `Ingress`, Gateway API, `NetworkPolicy`, `AdminNetworkPolicy`, DNS (CoreDNS integration), `kube-proxy`, CNI integration, dual-stack IPv4/IPv6, topology-aware routing.

Key repos: `kubernetes/kubernetes` (pkg/proxy/\*, pkg/controller/endpointslice/\*), `kubernetes-sigs/gateway-api`

---

### SIG Node

**Owns**: kubelet, CRI (container runtime interface), cgroup v2, resource management (`requests`/`limits`), device plugins, Dynamic Resource Allocation (DRA), in-place pod vertical scaling, `RuntimeClass`, pod lifecycle, `sysctl` support, node-level security (seccomp, AppArmor), huge pages, CPU/memory manager.

Key repos: `kubernetes/kubernetes` (pkg/kubelet/\*), `kubernetes-sigs/node-feature-discovery`

DRA (Dynamic Resource Allocation) is the next-generation device plugin model — watch SIG Node if you work with GPUs, FPGAs, or custom hardware.

---

### SIG Release

**Owns**: Release process and tooling, versioning policy, release cadence (4 releases/year), CI signal monitoring, branch management, release team structure, release notes, changelog.

Key repos: `kubernetes/sig-release`, `kubernetes/release`, `kubernetes/test-infra` (release jobs)

The release cycle: ~3 months per release. Enhancements freeze → code freeze → RC → release. SIG Release sets the dates; SIGs are responsible for their KEPs meeting the deadlines.

---

### SIG Scalability

**Owns**: Performance benchmarks and SLOs for 5000-node clusters, `perf-tests` framework, scalability testing infrastructure, performance review for KEPs (PRR consultation), API server performance, etcd performance, scheduler performance.

Key repos: `kubernetes/perf-tests`, `kubernetes-sigs/reference-docs`

Defined SLOs:
- API call latency p99 < 1s for non-list, non-watch requests
- Pod startup latency p99 < 5s (excluding image pull)
- Scheduler throughput: ≥100 pods/s for small pods on 5000-node cluster

---

### SIG Scheduling

**Owns**: `kube-scheduler`, Scheduling Framework plugin interface, preemption, `PriorityClass`, `PodDisruptionBudget` (co-owned with SIG Apps), `TopologySpreadConstraints`, `Descheduler` (kubernetes-sigs), `scheduler-plugins` (extension point examples).

Key repos: `kubernetes/kubernetes` (pkg/scheduler/\*), `kubernetes-sigs/descheduler`, `kubernetes-sigs/scheduler-plugins`

---

### SIG Security

**Owns**: Kubernetes threat model, CVE triage and response process, security audit coordination, SPIFFE/SPIRE integration direction, `PodSecurity` standards, security-relevant documentation, Hardening Guide.

Key repos: `kubernetes/sig-security` (reports, audits), coordinates with SIG Auth for implementation.

For SPIFFE integration: SIG Security owns the direction; SIG Auth owns the implementation. The `BoundServiceAccountTokens` feature (projected tokens with SPIFFE-compatible audience) came from this collaboration.

---

### SIG Storage

**Owns**: CSI spec integration, `PersistentVolume`/`PersistentVolumeClaim` lifecycle, `StorageClass`, volume plugin framework, volume snapshot controller, `VolumeAttributesClass` (dynamic QoS), `CSIMigration` (in-tree → CSI migration), `ReadWriteOncePod`.

Key repos: `kubernetes/kubernetes` (pkg/volume/\*, pkg/controller/volume/\*), `kubernetes-csi/external-snapshotter`, `kubernetes-csi/external-provisioner`

---

### SIG Testing

**Owns**: e2e test framework (`test/e2e/\*`), conformance test suite, CI infrastructure (`prow`), `kind` (Kubernetes in Docker), `kubetest2`, test flake triage, test-infra configuration.

Key repos: `kubernetes/test-infra`, `kubernetes-sigs/kind`, `kubernetes/kubernetes` (test/\*)

`kind` is the standard tool for local development and CI — runs a full multi-node cluster in Docker containers.

---

### SIG Windows

**Owns**: Windows node support, Windows container runtime integration, Windows-specific kubelet behavior, Windows CNI support, HostProcess containers, Windows-specific e2e tests.

Key repos: `kubernetes/kubernetes` (pkg/kubelet/winstats/\*, etc.), `kubernetes-sigs/windows-testing`

---

## Working Groups

Working Groups are time-bounded cross-SIG efforts. They dissolve when their goal is achieved or abandoned.

| WG | Goal | Status |
|---|---|---|
| WG Batch | Improve Job/CronJob for HPC and ML workloads (indexed jobs, job success/failure policy, backoff per index) | Active |
| WG Device Management | Dynamic Resource Allocation (DRA) — next-generation device plugin model for GPUs, FPGAs | Active |
| WG Structured Logging | Migrate all components from unstructured klog to contextual structured logging | Winding down |
| WG Policy | Cross-cutting policy enforcement standards (network policy, security policy) | Ongoing |
| WG IoT/Edge | Kubernetes for edge/IoT use cases | Active |
| WG Data Protection | Backup/restore standards, volume populator API | Active |

## Committees

| Committee | Role |
|---|---|
| Steering Committee | Overall project governance, SIG charter approval, conflict resolution |
| Security Response Committee | CVE triage, embargo coordination, security advisories |
| Code of Conduct Committee | CoC enforcement |

## Contributing

### Finding your entry point

1. **Pick a SIG** based on the area you care about (networking, scheduling, storage, etc.)
2. **Attend the public meeting** — all SIG meetings are on the [community calendar](https://calendar.google.com/calendar/r?cid=calendar.google.com_2_s6hd7a5i6u3m8i7a5k3jg1uf7c@group.calendar.google.com) and recorded
3. **Read the backlog** — GitHub issues in `kubernetes/kubernetes` or the relevant SIG repo tagged `good first issue` or `help wanted`
4. **Join the Slack channel** — `kubernetes.slack.com`, channels named `#sig-<name>`

### Membership ladder

```
Contributor → Member → Reviewer → Approver → SIG Lead / Chair
```

- **Member**: regular contributor, LGTM rights on own PRs. Requires: 5+ PRs merged, sponsored by 2 members.
- **Reviewer**: can LGTM others' PRs in their area. Requires: significant contribution history.
- **Approver**: can merge PRs (LGTM + approve). Listed in OWNERS files. Requires: deep domain expertise.
- **SIG Lead/Chair**: elected by SIG members. Runs meetings, drives roadmap, approves KEPs.

### Key repos

| Repo | What's there |
|---|---|
| `kubernetes/kubernetes` | The monorepo. Core components. |
| `kubernetes/enhancements` | KEPs, feature tracking, milestone planning |
| `kubernetes/community` | SIG charters, meeting notes, governance docs |
| `kubernetes/client-go` | Go client library (also in k/k as staging) |
| `kubernetes-sigs/*` | SIG-owned projects outside the main repo |
| `kubernetes/test-infra` | Prow CI, job configs, merge automation |

### The PR process

1. Sign the CLA (Linux Foundation)
2. Open a PR; prow assigns reviewers from OWNERS
3. Reviewer comments → iterate → `lgtm` label added
4. Approver (from OWNERS) adds `/approve`
5. Prow's tide controller merges when: LGTM + approve + CI green + no holds

`/hold` — blocks merge. `/cc @username` — requests review. `/assign @username` — assigns ownership. `/kind bug` — adds kind label. `/milestone v1.31` — sets milestone.
