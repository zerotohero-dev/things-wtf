# Architecture

A cluster has a **control plane** (masters) and a **data plane** (worker nodes). The control plane components are themselves just pods — Kubernetes runs itself.

## Control plane components

### kube-apiserver

The only component that reads/writes etcd. Stateless; horizontally scalable.

Responsibilities:

- Authentication (x509, OIDC, webhook, service account tokens)
- Authorization (RBAC, Node, Webhook modes)
- Admission (mutating → validating webhook chain + built-in plugins)
- Validation and defaulting (OpenAPI schema + CEL)
- Version conversion (between served API versions)
- Watch/list serving (streaming etcd events to clients)

All other components talk **only** to the API server — never to each other or etcd directly.

### etcd

Strongly consistent KV store using Raft. All cluster state lives here.

Key structure: `/registry/<group>/<resource>/<namespace>/<name>`

```
/registry/apps/deployments/default/nginx
/registry/core/pods/kube-system/coredns-abc12
/registry/apiextensions.k8s.io/customresourcedefinitions/foos.example.io
```

Values are protobuf-serialized API objects (not JSON — the API server converts). etcd watch events drive the informer/watch machinery upstream.

### kube-scheduler

Watches for unscheduled pods (`spec.nodeName == ""`). For each pod, runs a scheduling cycle:

1. **Filter** plugins remove infeasible nodes (resource fit, taints/tolerations, affinity)
2. **Score** plugins rank remaining nodes (spread, resource balance, topology)
3. **Bind** writes `spec.nodeName` to the API server

Custom scheduling logic via the [Scheduling Framework](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/) — implement plugin interfaces in Go and register with the framework.

### kube-controller-manager

Runs all built-in controllers in a single binary. Each controller runs its own goroutine + work queue. Partial list:

`deployment` · `replicaset` · `statefulset` · `daemonset` · `job` · `cronjob` · `namespace` · `serviceaccount` · `endpointslice` · `node-lifecycle` · `garbage-collector` · `ttl` · `horizontalpodautoscaler` · `persistentvolume` · `persistentvolumeclaim` · `resourcequota`

### cloud-controller-manager

Splits cloud-specific logic out of `kube-controller-manager`. Ships separately, implemented by cloud providers.

Controllers:

- **Node controller** — syncs cloud instance metadata (region, zone, instance type) onto Node objects
- **Route controller** — programs cloud VPC routes for pod CIDR ranges
- **Service controller** — manages cloud load balancers for `type: LoadBalancer` Services

### kubelet

Agent on every node. Core responsibilities:

- Watches PodSpecs assigned to its node via the API server
- Drives the container runtime (via CRI gRPC) to create/stop containers
- Runs liveness/readiness/startup probes and takes action on failures
- Reports node and pod status back to the API server via PATCH
- Exposes `/healthz`, `/metrics`, exec/attach/log endpoints on the kubelet API (port 10250)
- Calls CNI on pod creation/deletion to wire/unwire networking
- Manages volume mounting (calling CSI NodePublishVolume)

## Data plane

### kube-proxy

Programs `iptables` or `ipvs` rules to implement Service VIPs. Watches EndpointSlice objects and updates rules to match. Now largely optional — most CNI plugins (Cilium) replace it entirely with eBPF, which is more efficient and avoids conntrack table exhaustion at scale.

### Container runtime (CRI)

Any OCI-compatible runtime implementing the CRI gRPC interface. The kubelet calls:

```
CreateContainer → StartContainer → StopContainer → RemoveContainer
```

Common runtimes: `containerd` (default on most distros), `CRI-O`. Docker was removed as a direct runtime in 1.24 (use containerd's Docker-compatible shim if needed).

### CNI plugin

Called by the kubelet (via a shell exec) when a pod sandbox is created. Receives JSON config + environment variables, outputs JSON with the allocated IP and interface info.

The plugin is responsible for:

- Allocating a pod IP from the node's pod CIDR
- Creating a veth pair (one end in the pod netns, one on the host)
- Programming routing so the pod is reachable cluster-wide (flat network model)

Examples: Calico (BGP or VXLAN), Cilium (eBPF), Flannel (VXLAN), Weave, Antrea.

## Communication paths

```
kubectl            →  API server  →  etcd
controller-manager →  API server     (Watch, long-lived HTTP/2)
scheduler          →  API server     (Watch unscheduled pods, Bind)
kubelet            →  API server     (Watch assigned pods, PATCH status)
kubelet            →  CRI (containerd)  gRPC, local socket
kubelet            →  CNI plugin        exec, local binary
kubelet            →  CSI driver        gRPC, local socket
```

No component holds a direct connection to etcd except the API server. No component issues commands to another component — everything goes through the API server as a shared state store.

## API server request lifecycle

Every write request passes through this chain in order:

```
AuthN → AuthZ (RBAC) → Mutating Admission → Object Schema Validation
      → Validating Admission → etcd write → watch event fan-out
```

Read requests (GET, LIST, WATCH) skip admission and go to the API server's in-memory watch cache (backed by etcd), not etcd directly, unless `resourceVersion: "0"` is explicitly bypassed.

!!! warning "Webhook availability"
    Mutating and validating admission webhooks are in the critical path of every write. An unavailable webhook with `failurePolicy: Fail` blocks all matching requests. Always use `namespaceSelector` to exclude system namespaces, and run webhook servers with `topologySpreadConstraints` across zones.
