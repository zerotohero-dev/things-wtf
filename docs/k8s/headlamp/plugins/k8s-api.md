# Using the K8s API in Plugins

The `K8s` module provides typed resource classes with React hooks for `list`, `get`, and watch operations. All requests go through the `headlamp-server` proxy and respect the logged-in user's RBAC — if the user can't list pods, the hook returns an error.

```typescript
import { K8s } from '@kinvolk/headlamp-plugin/lib';
```

## Listing resources

`useList()` returns `[items, error]`. Items is `null` while loading.

```typescript
function PodCount() {
  const [pods, error] = K8s.ResourceClasses.Pod.useList();

  if (error) return <div>Error: {error.message}</div>;
  if (!pods)  return <div>Loading...</div>;
  return <div>{pods.length} pods</div>;
}
```

### With filters

```typescript
// filter by label selector
const [helmSecrets] = K8s.ResourceClasses.Secret.useList({
  labelSelector: 'owner=helm,status=deployed',
});

// filter by namespace
const [pods] = K8s.ResourceClasses.Pod.useList({
  namespace: 'production',
});

// combined
const [runningPods] = K8s.ResourceClasses.Pod.useList({
  namespace:     'default',
  fieldSelector: 'status.phase=Running',
});
```

## Getting a single resource

```typescript
function DeploymentStatus({ namespace, name }: { namespace: string; name: string }) {
  const [deploy, error] = K8s.ResourceClasses.Deployment.useGet(name, namespace);

  if (!deploy) return null;
  const { readyReplicas = 0, replicas = 0 } = deploy.jsonData.status;
  return <div>{readyReplicas}/{replicas} ready</div>;
}
```

## Available resource classes

```typescript
K8s.ResourceClasses.Pod
K8s.ResourceClasses.Deployment
K8s.ResourceClasses.StatefulSet
K8s.ResourceClasses.DaemonSet
K8s.ResourceClasses.ReplicaSet
K8s.ResourceClasses.Job
K8s.ResourceClasses.CronJob
K8s.ResourceClasses.Service
K8s.ResourceClasses.Ingress
K8s.ResourceClasses.ConfigMap
K8s.ResourceClasses.Secret
K8s.ResourceClasses.ServiceAccount
K8s.ResourceClasses.Node
K8s.ResourceClasses.Namespace
K8s.ResourceClasses.PersistentVolume
K8s.ResourceClasses.PersistentVolumeClaim
K8s.ResourceClasses.StorageClass
K8s.ResourceClasses.NetworkPolicy
K8s.ResourceClasses.CustomResourceDefinition
// ... and more
```

## Custom resources (CRDs)

Use `makeKubeObject` to create a typed class for any CRD:

```typescript
import { makeKubeObject } from '@kinvolk/headlamp-plugin/lib/lib/k8s/cluster';

class SpiffeEntry extends makeKubeObject('SpiffeEntry') {
  static apiEndpoint = makeKubeObject('SpiffeEntry').apiEndpoint(
    'spire.spiffe.io',   // API group
    'v1alpha1',          // version
    'spiffeentries',     // plural resource name
  );

  // add typed accessors for your CRD's spec fields
  get spiffeId(): string {
    return this.jsonData.spec?.spiffeId ?? '';
  }

  get selectors(): Record<string, string> {
    return this.jsonData.spec?.selectors ?? {};
  }
}

// use like any built-in resource
function SpiffeEntryList() {
  const [entries, error] = SpiffeEntry.useList();

  if (error) return <div>Error: {error.message}</div>;
  if (!entries) return <div>Loading...</div>;

  return (
    <ul>
      {entries.map(e => (
        <li key={e.metadata.uid}>{e.spiffeId}</li>
      ))}
    </ul>
  );
}
```

## Reading resource YAML / jsonData

Every resource instance exposes its raw Kubernetes object at `.jsonData`:

```typescript
const [deploy] = K8s.ResourceClasses.Deployment.useGet('my-app', 'default');

// access any field from the raw K8s object
const image    = deploy?.jsonData.spec?.template.spec.containers[0].image;
const replicas = deploy?.jsonData.spec?.replicas;
const labels   = deploy?.jsonData.metadata?.labels;
```

## Multi-cluster awareness

When Headlamp manages multiple clusters, hooks operate on the **currently selected cluster** automatically. To explicitly target a cluster, pass the cluster name:

```typescript
const [pods] = K8s.ResourceClasses.Pod.useList({
  cluster: 'production-west',
});
```

## Making raw API calls

For operations not covered by the hook API (PATCH, POST, DELETE, or non-standard endpoints):

```typescript
import { apiFactory } from '@kinvolk/headlamp-plugin/lib';

// raw GET
const resp = await fetch('/clusters/my-cluster/api/v1/namespaces/default/pods');
const data = await resp.json();

// using apiFactory for structured calls
const podAPI = apiFactory('', 'v1', 'pods');
await podAPI.delete('my-pod', 'default');
```

## Reaching in-cluster services (service proxy)

For services that aren't the Kubernetes API — like a Helm repo or internal tool:

```typescript
const base = window.__headlampBaseURL__ ?? '';
const resp = await fetch(`${base}/serviceproxy/default/my-service/api/data`);
const data = await resp.json();
```

See [Service Proxy](../service-proxy.md) for full details.

## Practical example: SPIFFE identity panel on Pod detail

```typescript title="src/index.tsx"
import { registerDetailsViewSection } from '@kinvolk/headlamp-plugin/lib';
import { K8s } from '@kinvolk/headlamp-plugin/lib';
import { SectionBox, NameValueTable } from '@kinvolk/headlamp-plugin/lib/CommonComponents';

registerDetailsViewSection({
  resource: K8s.ResourceClasses.Pod,
  section: (pod) => {
    const annotations = pod.metadata?.annotations ?? {};
    const spiffeId = annotations['spiffe.io/spiffe-id'];

    if (!spiffeId) return null;

    return (
      <SectionBox title="SPIFFE Identity">
        <NameValueTable
          rows={[
            { name: 'SPIFFE ID', value: spiffeId },
            { name: 'Trust Domain', value: spiffeId.split('/')[2] ?? '—' },
            { name: 'Workload', value: spiffeId.split('/').slice(3).join('/') ?? '—' },
          ]}
        />
      </SectionBox>
    );
  },
});
```
