# API Machinery

The API machinery is the foundational layer of Kubernetes extensibility. Understanding GVK/GVR, the informer pipeline, and patch semantics is essential for writing controllers and debugging API interactions.

## GVK & GVR

Every Kubernetes object is identified by two related concepts:

**GVK** (Group / Version / Kind) — identifies a *type schema*:

| Component | Meaning | Examples |
|---|---|---|
| Group | Logical family | `""` (core), `apps`, `batch`, `networking.k8s.io`, `rbac.authorization.k8s.io` |
| Version | Schema version | `v1`, `v1beta1`, `v1alpha1` |
| Kind | Type name | `Deployment`, `Pod`, `CustomResourceDefinition` |

**GVR** (Group / Version / Resource) — identifies a *REST endpoint*:

| Component | Meaning | Examples |
|---|---|---|
| Resource | Plural lowercase noun | `deployments`, `pods`, `customresourcedefinitions` |

The mapping between them:

```
GVK: apps/v1/Deployment  →  GVR: apps/v1/deployments
GVK: ""  /v1/Pod         →  GVR: ""  /v1/pods
```

This mapping lives in the `RESTMapper`. In client-go: `mapper.ResourceFor(gvk)`. In Go code, the Scheme maps GVK ↔ Go struct type.

### URL structure

```
# Core group (group = "")
/api/v1/namespaces/{ns}/pods/{name}
/api/v1/nodes/{name}

# Named groups
/apis/{group}/{version}/namespaces/{ns}/{resource}/{name}
/apis/apps/v1/namespaces/default/deployments/nginx
/apis/batch/v1/namespaces/default/jobs
/apis/custom.io/v1alpha1/namespaces/myns/foos/myfoo

# Sub-resources
/apis/apps/v1/namespaces/default/deployments/nginx/scale
/api/v1/namespaces/default/pods/mypod/log
/api/v1/namespaces/default/pods/mypod/exec
```

## API discovery

Clients discover available APIs before making requests. Two endpoints:

```bash
GET /api        → core group versions
GET /apis       → all named groups

GET /api/v1                      → resource list for core v1
GET /apis/apps/v1                → resource list for apps/v1
GET /apis/custom.io/v1alpha1     → resource list for your CRD group
```

Aggregated discovery (GA 1.30) returns all groups + resources in two requests:

```
GET /api?aggregated=true
GET /apis?aggregated=true
```

kubectl caches discovery documents in `~/.kube/cache/discovery/`. Stale cache causes "no matches for kind" errors — clear with `kubectl api-resources` or delete `~/.kube/cache/`.

## resourceVersion & watches

Every object has a `resourceVersion` field — a monotonically increasing etcd revision string:

```yaml
metadata:
  resourceVersion: "42891"
```

Semantics:

- Changes on every write (spec, status, metadata, labels — anything)
- Used for optimistic concurrency: include it in writes; stale writes get `409 Conflict`
- Passed to LIST/WATCH to resume from a known point

### Watch protocol

A watch is a long-lived HTTP/2 streaming request. The API server streams newline-delimited JSON events:

```
GET /apis/apps/v1/deployments?watch=1&resourceVersion=42891

{"type":"MODIFIED","object":{...}}
{"type":"DELETED","object":{...}}
{"type":"ADDED","object":{...}}
```

Error cases:

| Condition | HTTP response | Action |
|---|---|---|
| `resourceVersion` too old (compacted) | `410 Gone` | Re-list (RV=""), restart watch |
| Network timeout / server close | Connection closed | Resume with last known RV |
| RV="" | Start from current head | No missed events, but potentially stale |

The informer library handles all this automatically. Don't implement raw watches in application code.

### resourceVersion semantics on LIST

| `resourceVersion` value | Meaning |
|---|---|
| `""` (empty) | Return from API server cache (may be slightly stale). Most efficient. |
| `"0"` | Same as empty in practice. |
| Specific value | Return only if cluster state is at least that version. |
| `"0"` + `resourceVersionMatch: Exact` | Return exactly from that revision (expensive, hits etcd). |

## generation & observedGeneration

Two separate revision counters:

- `metadata.generation` — increments on every **spec** change. Status updates don't increment it.
- `status.observedGeneration` — set by the controller to the `generation` value it last successfully processed.

Use this pattern to detect controller drift:

```go
if obj.Generation != obj.Status.ObservedGeneration {
    // controller hasn't caught up to latest spec yet
}
```

Always set `observedGeneration` in your status update:

```go
obj.Status.ObservedGeneration = obj.Generation
```

## Patch strategies

Four patch types, each with different semantics:

### JSON Patch (RFC 6902)

Array of operations. Positional — fragile for lists.

```json
[
  {"op": "replace", "path": "/spec/replicas", "value": 3},
  {"op": "add",     "path": "/metadata/labels/env", "value": "prod"},
  {"op": "remove",  "path": "/metadata/annotations/old-key"}
]
```

```bash
kubectl patch deploy/myapp --type=json \
  -p='[{"op":"replace","path":"/spec/replicas","value":3}]'
```

### Merge Patch (RFC 7396)

Partial object. Null = delete field. Lists are **replaced entirely** — danger for `containers[]`.

```bash
kubectl patch deploy/myapp --type=merge \
  -p='{"spec":{"replicas":3}}'
```

### Strategic Merge Patch

Kubernetes-specific extension to merge patch. List fields have **merge keys** defined in the Go struct tags:

```go
// containers merges by "name"
Containers []Container `json:"containers" patchStrategy:"merge" patchMergeKey:"name"`
```

Patching one container by name doesn't replace others:

```bash
kubectl patch deploy/myapp --type=strategic \
  -p='{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"myapp:2.0"}]}}}}'
```

!!! warning "Strategic merge patch doesn't work on CRDs"
    SMP merge keys are defined in Go struct tags in the Kubernetes source. CRDs have no such tags — SMP falls back to merge patch behavior (list replacement). Use Server-Side Apply for CRDs.

### Server-Side Apply (GA 1.22)

Field-level ownership tracking. The API server tracks which manager owns which field.

```bash
kubectl apply --server-side --field-manager=my-tool -f myapp.yaml
```

Conflict: two managers try to own the same field → `409 Conflict` with details. Force-take ownership:

```bash
kubectl apply --server-side --force-conflicts --field-manager=my-tool -f myapp.yaml
```

In Go with controller-runtime:

```go
err := r.Patch(ctx, obj, client.Apply, client.FieldOwner("my-controller"), client.ForceOwnership)
```

SSA is the correct approach for controllers that manage partial objects — they own only the fields they care about, and other managers (user, Helm, etc.) can coexist.

## Informer architecture

The informer is the standard pattern for watching resources without hammering the API server.

```
API server (ListWatch)
    ↓
Reflector  →  ListWatch implementation; handles 410 Gone (re-list + re-watch)
    ↓
DeltaFIFO  →  queue of (object, delta-type) pairs; deduplicates
    ↓
Indexer    →  thread-safe in-memory store; GVK-indexed; supports label queries
    ↓
Event handlers (AddFunc, UpdateFunc, DeleteFunc)
    ↓
WorkQueue  →  rate-limited, deduplicating; items are NamespacedName keys
    ↓
Reconciler goroutines (n workers)
```

Key property: **all reads in the reconcile loop come from the Indexer (local cache)** — never the API server directly. This means the reconciler never adds to the API server's read load, no matter how many controllers run.

### SharedInformerFactory

Multiple controllers for the same resource type share a single informer/watch:

```go
factory := informers.NewSharedInformerFactory(client, 30*time.Second)
deployInformer := factory.Apps().V1().Deployments()
podInformer    := factory.Core().V1().Pods()

factory.Start(stopCh)
factory.WaitForCacheSync(stopCh)  // block until initial list is complete
```

The factory deduplicates by GVR — two controllers watching Deployments share one HTTP watch stream to the API server.

### Always wait for cache sync

```go
if !cache.WaitForCacheSync(stopCh, r.deploymentsSynced, r.podsSynced) {
    return fmt.Errorf("timed out waiting for caches to sync")
}
```

Starting reconcilers before the cache is synced causes false "not found" errors for objects that exist but haven't populated the local cache yet.

## Object metadata deep dive

```yaml
metadata:
  uid: 550e8400-e29b-41d4-a716-446655440000
  # Immutable. Unique forever (even after object deletion + recreation).
  # etcd uses (namespace, name) for storage; uid identifies a specific instance.

  resourceVersion: "42891"
  # etcd revision. String — compare only for equality, never parse as integer.
  # Changes on every write to any field (spec, status, labels, annotations, finalizers).

  generation: 3
  # Incremented only on spec changes. Status and metadata changes don't increment.
  # Use generation/observedGeneration to detect pending reconciliation.

  creationTimestamp: "2024-01-15T10:00:00Z"

  deletionTimestamp: "2024-01-16T10:00:00Z"
  # Set when DELETE is received AND finalizers are present.
  # Object persists until finalizers[] is empty.
  deletionGracePeriodSeconds: 30
  # Grace period for SIGTERM before SIGKILL on container stop.

  managedFields:
  # Server-Side Apply field ownership map. One entry per field-manager.
  # Can be stripped with --show-managed-fields=false or server-side.
```
