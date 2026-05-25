# App Catalog

The App Catalog is a Headlamp plugin (maintained in [headlamp-k8s/plugins](https://github.com/headlamp-k8s/plugins)) that provides a Helm-based application marketplace inside the Headlamp UI. As of 2025 it supports both **Artifact Hub** and **vanilla Helm repos** as sources, and can run entirely in-cluster using the service proxy.

## Prerequisites

- Headlamp deployed with `--enable-helm` (see [--enable-helm](enable-helm.md))
- OIDC authentication (service account token auth has a [known issue](https://github.com/kubernetes-sigs/headlamp/issues/4788) with Helm release listing)

## Install the App Catalog plugin

=== "Via pluginsManager (recommended)"
    ```yaml title="values.yaml"
    config:
      enableHelm: true
      watchPlugins: true

    pluginsManager:
      enabled: true
      configContent: |
        plugins:
          - name: app-catalog
            source: https://artifacthub.io/packages/headlamp/headlamp-plugins/headlamp_app_catalog
            version: latest
        installOptions:
          parallel: true
    ```

    ```bash
    helm upgrade headlamp headlamp/headlamp \
      --namespace kube-system -f values.yaml
    ```

=== "Manual tarball"
    ```bash
    # download the plugin tarball from Artifact Hub or GitHub releases
    # extract into the Headlamp plugins dir
    tar -xzf headlamp_app_catalog-*.tar.gz \
      -C ~/.config/Headlamp/plugins/
    ```

## Deploy an in-cluster Helm repo

The App Catalog needs a Helm repo it can reach. The simplest self-hosted option is ChartMuseum. For production, consider Harbor (OCI + Helm) or a private registry.

=== "ChartMuseum (quick start)"
    ```bash
    helm repo add chartmuseum https://chartmuseum.github.io/charts
    helm repo update

    helm install my-catalog chartmuseum/chartmuseum \
      --namespace default \
      --set env.open.STORAGE=local \
      --set persistence.enabled=false

    # verify
    kubectl get svc -n default | grep my-catalog
    # → my-catalog-chartmuseum   ClusterIP   10.96.x.x   80/TCP
    ```

=== "ChartMuseum with persistent storage"
    ```yaml title="chartmuseum-values.yaml"
    env:
      open:
        STORAGE: local
        DISABLE_API: "false"
        ALLOW_OVERWRITE: "true"

    persistence:
      enabled: true
      storageClass: standard   # adjust for your cluster
      size: 5Gi
    ```

    ```bash
    helm install my-catalog chartmuseum/chartmuseum \
      --namespace default \
      -f chartmuseum-values.yaml
    ```

=== "Harbor (production)"
    Harbor provides OCI and Helm repo support with authentication. Deploy via the [Harbor Helm chart](https://github.com/goharbor/harbor-helm) and configure App Catalog with the Helm repo URL from Harbor's UI.

## Configure App Catalog to use the in-cluster repo

Once the plugin loads, navigate to **Settings → App Catalog** in the Headlamp UI. Add a new repository:

| Field | Value |
|---|---|
| **Name** | `My Catalog` (arbitrary label) |
| **URL** | `/serviceproxy/default/my-catalog-chartmuseum/` |
| **Type** | `Helm` |

!!! tip "Base URL"
    If Headlamp runs with a `--base-url` prefix (e.g. `/headlamp`), the URL must include it:
    ```
    /headlamp/serviceproxy/default/my-catalog-chartmuseum/
    ```

The App Catalog plugin calls:

- `{repo-url}/api/charts` — enumerate all charts
- `{repo-url}/api/charts/{name}` — fetch chart metadata and versions
- `{repo-url}/api/charts/{name}/{version}.tgz` — download for install/upgrade

## Pushing charts to your in-cluster repo

```bash
# package your chart
helm package ./my-chart

# push to ChartMuseum (requires DISABLE_API=false)
curl -X POST \
  --data-binary "@my-chart-0.1.0.tgz" \
  http://localhost:8080/serviceproxy/default/my-catalog-chartmuseum/api/charts

# or via kubectl port-forward to push directly
kubectl port-forward -n default service/my-catalog-chartmuseum 8888:80 &
helm cm-push my-chart-0.1.0.tgz http://localhost:8888
```

## What App Catalog shows

- All charts in the configured repos with name, description, and icon
- Current installed version vs latest available version for each chart
- Installation form with configurable values
- Upgrade/rollback controls for installed releases
- Helm release history

## Troubleshooting

**App Catalog shows "failed to fetch charts"**

1. Confirm `--enable-helm` is active: `kubectl logs deployment/headlamp -n kube-system | grep helm`
2. Confirm the service proxy URL is correct (namespace, service name, base URL prefix)
3. Test the service proxy directly:
   ```bash
   curl http://localhost:8080/serviceproxy/default/my-catalog-chartmuseum/api/charts
   ```
4. Check Headlamp RBAC includes `services/proxy` verbs

**Helm release listing returns 403**

This is the [known issue #4788](https://github.com/kubernetes-sigs/headlamp/issues/4788) with service account token auth. Switch to OIDC authentication.

**Plugin not loading**

```bash
kubectl logs -n kube-system -l app.kubernetes.io/component=plugins-manager
# look for download or extraction errors
```

---

## The Elephant in the Room: Silent Failure Analysis

The App Catalog is shipped and functional in the desktop application but **silently non-operational in every default in-cluster deployment**. There are 2 code bugs and 5 undocumented deployment requirements. None produce error messages.

This section documents findings from a deep codebase investigation and call-graph analysis. See [Technical Debt](../../../docs-internal/headlamp/technical-debt.md) for the full danger zone inventory.

### The 7 Gaps

| # | Category | What's Broken | Impact | Fix |
|---|----------|--------------|--------|-----|
| 1 | **Code Bug** | `helmRouteReleaseHandler` guards `setTokenFromCookie()` behind OIDC check | ALL Helm release operations return `system:anonymous` in non-OIDC deployments | Make `setTokenFromCookie()` unconditional ([tracked upstream](https://github.com/kubernetes-sigs/headlamp/issues/4788)) |
| 2 | **Code Bug** | `RouteSwitcher.tsx` uses identical React key `getCluster()` for all `<AuthRoute>` components | Dynamically registered routes (from plugin async callbacks) never resolve — 404 on click | Use `route.path` in key |
| 3 | **Deployment** | app-catalog plugin not in container image | Plugin never loads in-cluster. No "Apps" sidebar section. | Add to `container/build-manifest.json` or install via sidecar |
| 4 | **Deployment** | `--proxy-urls` not set (desktop sets it automatically) | External proxy rejects ArtifactHub API requests | Add `--proxy-urls=https://artifacthub.io/*` |
| 5 | **Deployment** | No catalog Service template in Helm chart | Plugin discovers zero catalogs, registers nothing | Create Service with `catalog.headlamp.dev/is-catalog` label |
| 6 | **Deployment** | `catalog.headlamp.dev/protocol` annotation undocumented | Sidebar entry appears but page route never registered — 404 | Add annotation (`helm` or `artifacthub`) |
| 7 | **Architecture** | ExternalName Service doesn't work through service proxy | TLS/SNI failures when proxying to external hostnames | Deploy in-cluster reverse proxy |

### Why It Matters

**7 failure modes. 0 error messages in the default case. 0 log lines in 5 of the 7 cases.**

The cumulative effect: an operator deploys Headlamp with `enableHelm: true`, sees no "Apps" section, no errors, no logs, and concludes the feature does not exist in the in-cluster version. **This is exactly what happened during the VKS team evaluation.**

### Desktop vs. In-Cluster Parity Gap

The desktop app ships with all 7 items pre-configured:

| Requirement | Desktop | In-Cluster |
|------------|---------|------------|
| Plugin installed | Bundled in `app-build-manifest.json` | Must install via sidecar or initContainer |
| `--proxy-urls` | Set automatically from build manifest | Must configure manually |
| Catalog discovery | Uses different code path (no Service labels needed) | Requires Service with specific label |
| Protocol annotation | Not needed (uses hardcoded ArtifactHub path) | Required but undocumented |
| Reverse proxy | Direct outbound HTTP from Electron | Need in-cluster nginx for external sources |
| OIDC cookie auth | Bypassed (desktop auth model) | Bug #1: cookie auth gated behind OIDC check |
| Route registration | Static (plugin loaded at build time) | Bug #2: React key collision breaks dynamic routes |

### The Discovery Protocol (Undocumented)

The app-catalog plugin discovers catalogs via a K8s Service label convention that is documented **nowhere** in the repository:

```
GET /api/v1/services?labelSelector=catalog.headlamp.dev/is-catalog=
```

For each discovered Service, the plugin reads annotations:

| Annotation | Required | Values | Purpose |
|-----------|----------|--------|---------|
| `catalog.headlamp.dev/is-catalog` | Yes (label) | `""` (empty) | Triggers plugin discovery |
| `catalog.headlamp.dev/name` | Yes | Any string | Internal identifier |
| `catalog.headlamp.dev/displayName` | Yes | Any string | Shown in UI |
| `catalog.headlamp.dev/protocol` | Yes | `helm` or `artifacthub` | Determines which handler registers routes |

Without the `protocol` annotation, the sidebar entry registers (unconditional) but the page route does not (conditional on protocol). Clicking the sidebar entry shows a 404.

### Root Cause: Code Bug #1

`backend/cmd/headlamp.go` line 1381-1383, function `helmRouteReleaseHandler`:

```go
// BEFORE (buggy): only extracts token when OIDC is configured
if c.UseInCluster && context.OidcConf != nil {
    setTokenFromCookie(r, clusterName)
}

// AFTER (fixed): unconditional, matches helmRouteRepositoryHandler behavior
setTokenFromCookie(r, clusterName)
```

The `setTokenFromCookie()` function is a no-op when no cookie exists. The repository handler (immediately below in the same file) already calls it unconditionally without issues. The inconsistency went unnoticed because desktop and OIDC deployments bypass this path.

### Root Cause: Code Bug #2

`frontend/src/components/App/RouteSwitcher.tsx` line 72-73:

```tsx
// BEFORE: all routes share same key — React can't distinguish them
key={getCluster()}    // e.g., "main" for every route

// AFTER: each route has unique key — React reconciliation works
key={`${route.path}-${getCluster()}`}
```

Static routes work because they exist from the initial render. Dynamic routes (registered inside async callbacks after `fetchCatalogs()` resolves) fail because React cannot reconcile them as new children when all siblings share the same key.

### Complete Fix Deployment

See [VKS Deployment Guide](../../../docs-internal/headlamp/vks-deployment.md#app-catalog-wiring) for the full step-by-step deployment including code fixes, catalog Service, and reverse proxy.
