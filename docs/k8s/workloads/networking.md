# Networking

## The Kubernetes network model

Three rules, guaranteed by the platform:

1. Pods can communicate with all other pods without NAT
2. Nodes can communicate with all pods without NAT
3. The IP a pod sees for itself is the same IP others see for it

This flat network model is implemented by the CNI plugin. The API server enforces the model; the CNI plugin implements it.

## Service

A stable virtual IP (ClusterIP) in front of a dynamic set of pods. kube-proxy (or eBPF) programs the packet-forwarding rules. EndpointSlice objects track the current healthy pod IPs behind a Service.

### Service types

| Type | Behavior |
|---|---|
| `ClusterIP` | VIP reachable only inside the cluster. Default. kube-dns creates an A record: `<svc>.<ns>.svc.cluster.local → ClusterIP`. |
| `NodePort` | Allocates a port (30000–32767) on every node. Traffic to `node:nodePort` is forwarded to the Service. ClusterIP still exists. |
| `LoadBalancer` | Requests a cloud LB. cloud-controller-manager provisions it and writes the external IP to `.status.loadBalancer.ingress`. Implies NodePort. |
| `ExternalName` | CNAME to an external DNS name. No proxying; CoreDNS does the redirect. No selector, no endpoints. |
| Headless (`clusterIP: None`) | No VIP. DNS returns individual pod IPs. Required for StatefulSets. kube-proxy creates no rules. |

### Session affinity

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
```

Routes all requests from the same client IP to the same pod. Implemented by iptables/ipvs. Not useful with kube-proxy in iptables mode at scale — use application-level session routing instead.

### Internal traffic policy

```yaml
spec:
  internalTrafficPolicy: Local   # only route to endpoints on the same node
```

Useful for node-local services (metrics aggregators, log forwarders). Falls back to cluster-wide routing if no local endpoint exists (unless `externalTrafficPolicy: Local` — which drops the packet).

## EndpointSlice

Replaced the `Endpoints` resource (which was a single unbounded list — problematic at scale). Each slice holds up to 100 endpoints. Multiple slices per Service are normal.

```yaml
addressType: IPv4
endpoints:
- addresses: ["10.0.1.42"]
  conditions: {ready: true, serving: true, terminating: false}
  targetRef: {kind: Pod, name: myapp-abc12}
  nodeName: node-1
  zone: us-west-2a
```

The EndpointSlice controller creates and updates slices; kube-proxy/Cilium watches them to program forwarding rules.

**Topology-aware routing** (`trafficDistribution: PreferClose`, GA 1.31): prefers endpoints in the same zone as the client. The EndpointSlice hints field encodes zone topology. Cilium and kube-proxy both implement it.

## Ingress

L7 HTTP routing. The `Ingress` object is thin — it's just routing rules. An Ingress controller (nginx, Traefik, Contour, Envoy Gateway, etc.) watches Ingress objects and programs itself.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts: [myapp.example.com]
    secretName: myapp-tls          # kubernetes.io/tls Secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service: {name: api-svc, port: {number: 80}}
      - path: /
        pathType: Prefix
        backend:
          service: {name: frontend-svc, port: {number: 80}}
```

`IngressClass` selects which controller handles this Ingress. Allows multiple ingress controllers in one cluster.

## Gateway API

*GA since 1.31. Successor to Ingress.*

Role-separated, expressive API for L4–L7 routing.

```
GatewayClass   — infra team: which controller + LB config
    ↓
Gateway        — platform team: listener config, TLS, hostnames
    ↓
HTTPRoute      — app team: path/header routing to Services
TCPRoute       — L4 TCP routing
TLSRoute       — TLS passthrough
GRPCRoute      — gRPC-specific routing (GA 1.31)
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  parentRefs:
  - name: prod-gateway
  hostnames: [myapp.example.com]
  rules:
  - matches:
    - path: {type: PathPrefix, value: /api}
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add: [{name: X-Source, value: gateway}]
    backendRefs:
    - name: api-svc
      port: 80
      weight: 100
```

Key advantages over Ingress: standardized across implementations, supports traffic splitting (canary via weights), header manipulation, cross-namespace references, extensibility via policy attachment.

## NetworkPolicy

Pod-level firewall. **Additive**: no NetworkPolicy = allow all; any policy selecting a pod creates a default deny on the selected direction, then adds back what the rules allow.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  podSelector:
    matchLabels: {app: backend}
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels: {kubernetes.io/metadata.name: frontend}
    - podSelector:
        matchLabels: {app: frontend}
    ports: [{port: 8080, protocol: TCP}]
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
  - ports: [{port: 53, protocol: UDP}]   # DNS — always required for egress
```

!!! note "from is OR between list items, AND within an item"
    ```yaml
    from:
    - namespaceSelector: {...}   # item 1
    - podSelector: {...}         # item 2
    ```
    Allows traffic from pods matching either selector (OR). To require *both* conditions (AND), use combined selectors within a single list item:
    ```yaml
    from:
    - namespaceSelector: {...}
      podSelector: {...}         # same item = AND
    ```

Requires a CNI that implements NetworkPolicy. Calico, Cilium, and Antrea all do. Flannel does not (use Calico on top of Flannel for policy enforcement).

## CoreDNS

Default cluster DNS since 1.13. Configured via `ConfigMap/coredns` in `kube-system`.

Pod DNS resolution order with `dnsPolicy: ClusterFirst`:

1. `<name>.<ns>.svc.cluster.local`
2. `<name>.svc.cluster.local`
3. `<name>.cluster.local`
4. Upstream resolver (host's `/etc/resolv.conf`)

Search domains added to every pod's `/etc/resolv.conf`:
```
search <ns>.svc.cluster.local svc.cluster.local cluster.local
```

This means `curl http://myservice` from a pod in the same namespace resolves correctly. From a different namespace: `curl http://myservice.othernamespace`.

Pod DNS policies:

| Policy | Behavior |
|---|---|
| `ClusterFirst` | Non-FQDN queries go to CoreDNS first. Default. |
| `ClusterFirstWithHostNet` | Same, for `hostNetwork: true` pods. |
| `Default` | Inherits node's DNS config directly. |
| `None` | Custom DNS config via `spec.dnsConfig`. |
