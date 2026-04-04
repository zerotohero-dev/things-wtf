# Service Proxy

The service proxy is a routing feature of `headlamp-server` (activated by `--enable-helm`) that allows the browser and plugins to reach **any Kubernetes Service by name**, without the browser having direct cluster network access.

## How it works

```
Plugin fetch('/serviceproxy/default/my-helm-repo/api/charts')
    │
    ▼
headlamp-server
    ├── authenticate request (token or OIDC session)
    ├── validate: does service "my-helm-repo" exist in namespace "default"?
    └── forward to http://my-helm-repo.default.svc.cluster.local/api/charts
            │
            ▼
        Response returns to plugin via headlamp-server
```

The cluster network sees the request as coming from the **Headlamp pod** — not from the user's browser. This is essential for in-cluster deployments where the browser can't reach `*.svc.cluster.local` addresses.

## URL structure

```
/serviceproxy/{namespace}/{service-name}/{path...}
```

| Segment | Example | Description |
|---|---|---|
| `namespace` | `default` | Kubernetes namespace of the target service |
| `service-name` | `my-chartmuseum` | Name of the Kubernetes Service |
| `path` | `api/charts` | Path forwarded to the service |

If Headlamp has a `--base-url` set (e.g. `/headlamp`), the full path becomes:

```
/headlamp/serviceproxy/{namespace}/{service-name}/{path...}
```

## Using the service proxy from a plugin

```typescript
// Direct fetch — works when base URL is /
const resp = await fetch('/serviceproxy/default/my-helm-repo/api/charts');
const charts = await resp.json();

// With base URL awareness (safer)
const base = window.__headlampBaseURL__ ?? '';
const resp = await fetch(`${base}/serviceproxy/default/my-helm-repo/api/charts`);
```

For App Catalog, the proxy URL is configured in the plugin's settings UI — you don't need to hardcode it in plugin code.

## Authentication

The service proxy inherits the logged-in user's session. Every request forwarded through the proxy carries the user's token (or OIDC access token) in the `Authorization` header.

!!! warning "Known issue with service account token auth"
    With non-OIDC (service account token) authentication, the `Authorization` header is not correctly forwarded to the backend service. This causes Helm release listing to fail with `403 Forbidden`. Track [issue #4788](https://github.com/kubernetes-sigs/headlamp/issues/4788). **Workaround: use OIDC authentication.**

## RBAC requirements

For the proxy to forward requests, the Headlamp service account needs:

```yaml
rules:
  - apiGroups: [""]
    resources: ["services/proxy"]
    verbs: ["get", "post", "put", "delete", "patch"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list"]
```

The **target service** also needs to accept requests from the Headlamp pod's IP or service account, depending on its own access controls.

## Example: forwarding to ChartMuseum

1. ChartMuseum service in namespace `default`, service name `my-catalog-chartmuseum`
2. Plugin or browser fetches: `/serviceproxy/default/my-catalog-chartmuseum/api/charts`
3. `headlamp-server` forwards to: `http://my-catalog-chartmuseum.default.svc.cluster.local/api/charts`
4. ChartMuseum returns the chart list JSON

No firewall rules, no Ingress, no direct network path needed from the developer's laptop to the cluster's service network.
