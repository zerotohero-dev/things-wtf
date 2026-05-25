# API Aggregation

The aggregation layer extends the Kubernetes API with custom API servers that are proxied through `kube-apiserver`. Registered groups appear under `/apis/<group>/<version>` alongside built-in APIs.

## CRDs vs aggregated API servers

Choose CRDs by default. Reach for aggregated APIs only when CRDs genuinely can't serve your needs.

| Factor | CRD | Aggregated API |
|---|---|---|
| Storage | etcd (automatic) | Custom (any backend) |
| Semantics | CRUD only | Any HTTP verb, streaming, websockets |
| Discovery | Automatic | Must implement `/apis/<group>` endpoints |
| Auth | Delegated to main API server (automatic) | Must call `SubjectAccessReview` manually |
| Availability | API server serves CRDs directly | Extension server outage = 503 for that group |
| Operational cost | Low | High (deploy + operate another API server) |
| OpenAPI/validation | Structural schema + CEL | Must serve `/openapi/v2` or `/openapi/v3` |

**Use CRDs when**: CRUD semantics are sufficient, you don't need custom storage backends, and CEL validation covers your rules.

**Use aggregated APIs when**: you need long-running requests (streaming logs, exec, attach), non-etcd storage (in-memory, external DB), per-object access control beyond RBAC, or custom serialization formats.

Real-world examples: `metrics-server` (`metrics.k8s.io`), `custom-metrics-adapter` (`custom.metrics.k8s.io`), `kube-aggregator` itself.

## APIService registration

```yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  version: v1beta1
  service:
    namespace: kube-system
    name: metrics-server
    port: 443
  caBundle: <base64-encoded CA>      # used to verify the extension server's TLS cert
  insecureSkipTLSVerify: false       # never true in production
  groupPriorityMinimum: 100          # ordering in discovery
  versionPriority: 100
```

After registration, `kube-aggregator` (inside `kube-apiserver`) proxies all requests to `metrics.k8s.io/v1beta1` to the metrics-server Service.

## Extension server requirements

An extension API server must:

1. **Implement discovery endpoints**:
   - `GET /apis` → `APIGroupList`
   - `GET /apis/<group>` → `APIGroup`
   - `GET /apis/<group>/<version>` → `APIResourceList`

2. **Implement resource endpoints** for each served resource

3. **Delegate authentication**: the main API server adds `X-Remote-User`, `X-Remote-Group`, `X-Remote-Extra-*` headers to proxied requests. The extension server trusts these (after verifying the request came from the main API server via client cert).

4. **Delegate authorization**: call `SubjectAccessReview` against the main API server for each request:
   ```go
   sar := &authorizationv1.SubjectAccessReview{
       Spec: authorizationv1.SubjectAccessReviewSpec{
           User:   req.Header.Get("X-Remote-User"),
           Groups: req.Header["X-Remote-Group"],
           ResourceAttributes: &authorizationv1.ResourceAttributes{
               Namespace: namespace,
               Verb:      "get",
               Group:     "metrics.k8s.io",
               Resource:  "nodes",
               Name:      nodeName,
           },
       },
   }
   ```

5. **Serve TLS** — `kube-aggregator` verifies the extension server's certificate using the `caBundle` in the APIService.

6. **Serve OpenAPI** — `GET /openapi/v2` and/or `GET /openapi/v3` for kubectl completion and validation.

## apiserver-builder

The `apiserver-builder` project (kubernetes-sigs) provides scaffolding for extension API servers, similar to kubebuilder for CRD-based operators. It generates the boilerplate for discovery, storage, and auth delegation.

## Availability impact

!!! warning "Extension server outages fail all requests for that group"
    Unlike CRDs (served directly by the main API server), aggregated API groups depend on the extension server being available. If `metrics-server` crashes, `kubectl top` and HPA CPU metrics both fail. Design extension servers for HA (multiple replicas + PDB) and monitor their availability separately.

    `kube-aggregator` does not cache responses — every request is proxied live.

## Local APIService (no backend)

For groups where no external server exists (e.g., during migration):

```yaml
spec:
  group: legacy.example.io
  version: v1
  insecureSkipTLSVerify: true
  # No service: field — requests return 503 immediately
```

Used to pre-register a group before the extension server is deployed, or to disable a group by leaving it with no backend.
