# --enable-helm

`--enable-helm` is a backend flag introduced in **v0.37.0** that activates two things simultaneously:

1. A **Helm API endpoint** on `headlamp-server` for enumerating and managing Helm releases inside the cluster using the Go Helm SDK (no `helm` binary required)
2. An **authenticated service proxy** at `/serviceproxy/{namespace}/{service}/{path}` that plugins use to reach in-cluster services without the browser touching the cluster network

## Enabling it

=== "Server flag (direct)"
    ```bash
    ./headlamp-server \
      --enable-helm \
      --kubeconfig ~/.kube/config \
      --plugins-dir ~/.config/Headlamp/plugins
    ```

=== "Helm chart (in-cluster)"
    ```yaml title="values.yaml"
    config:
      enableHelm: true
    ```

    ```bash
    helm upgrade headlamp headlamp/headlamp \
      --namespace kube-system \
      -f values.yaml
    ```

=== "Verify it's active"
    ```bash
    kubectl logs -n kube-system deployment/headlamp | grep -i helm
    # expect: "Helm support enabled" or similar on startup
    ```

## What it enables

### Helm release management

Once enabled, Headlamp can read Helm release metadata from the cluster. Helm stores releases as Kubernetes `Secrets` with the label `owner=helm`. The backend reads these using the Go [Helm SDK](https://helm.sh/docs/topics/advanced/) (same SDK used by Flux) — no shell-out to a binary.

Headlamp's service account needs the following permissions:

```yaml
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["list", "get"]
    # add "create", "update", "delete" to allow install/upgrade/uninstall
```

!!! tip
    Scope the `secrets` permission per-namespace if your users should only manage Helm releases in specific namespaces. Helm secrets are always in the namespace of the release.

### Service proxy

The service proxy is documented in detail in [Service Proxy](service-proxy.md). At a high level: it allows any plugin to reach any Kubernetes Service by name and namespace, using a URL like:

```
/serviceproxy/{namespace}/{service-name}/{path...}
```

The App Catalog plugin uses this to query in-cluster Helm repos without requiring the browser to have direct cluster network access.

## RBAC requirements

The Headlamp pod's service account needs these additional permissions when `--enable-helm` is active:

```yaml title="headlamp-helm-rbac.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: headlamp-helm
rules:
  # read Helm release secrets
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["list", "get"]
  # service proxy: allow subresource access to services
  - apiGroups: [""]
    resources: ["services/proxy"]
    verbs: ["get", "post", "put", "delete", "patch"]
  # service proxy: discover services
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list"]
```

## Version history

| Version | Change |
|---|---|
| v0.37.0 | `--enable-helm` introduced; service proxy added; App Catalog updated to use `/serviceproxy` |
| v0.37.0 | Vanilla Helm repo support added to App Catalog (not just Artifact Hub) |
| v0.37.0 | `--oidc-use-pkce` flag added |
