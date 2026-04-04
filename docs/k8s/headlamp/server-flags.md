# Server Flags Reference

Quick reference for `headlamp-server` command-line flags and their Helm chart equivalents.

## Core flags

| Flag | Helm values key | Default | Description |
|---|---|---|---|
| `--enable-helm` | `config.enableHelm` | `false` | Activate Helm API endpoint and service proxy. Required for App Catalog in-cluster mode and Helm release management. |
| `--watch-plugins-changes` | `config.watchPlugins` | `false` | Reload plugins when the plugins directory changes. Essential for development and pluginsManager sidecar. |
| `--plugins-dir` | `config.pluginsDir` | platform default | Override the plugin discovery directory. Default: `~/.config/Headlamp/plugins` on Linux/Mac, `%APPDATA%\Headlamp\plugins` on Windows. |
| `--kubeconfig` | `env.KUBECONFIG` | in-cluster SA | Explicit kubeconfig path(s). Colon-separated for multiple. Falls back to in-cluster service account when unset. |
| `--base-url` | `config.baseURL` | `/` | Path prefix when Headlamp is served from a sub-path (e.g. `/headlamp`). Required for path-based Ingress routing. |
| `--port` | `service.port` | `4466` | Port the backend server listens on. |
| `--insecure-skip-tls-verify` | `config.insecureSkipTlsVerify` | `false` | Skip TLS verification for cluster connections. **Do not use in production.** |

## OIDC flags

| Flag | Helm values key | Default | Description |
|---|---|---|---|
| `--oidc-client-id` | `config.oidc.clientID` | — | OIDC application client ID. |
| `--oidc-client-secret` | `config.oidc.clientSecret` | — | OIDC client secret. Prefer injecting via environment variable from a Kubernetes Secret. |
| `--oidc-issuer-url` | `config.oidc.issuerURL` | — | OIDC issuer discovery URL. Must expose a `/.well-known/openid-configuration` endpoint. |
| `--oidc-scopes` | `config.oidc.scopes` | `profile,email` | Comma-separated OIDC scopes to request. Include `groups` for group-based RBAC. |
| `--oidc-use-pkce` | `config.oidc.usePKCE` | `false` | Enable PKCE. Recommended for all new deployments, required by some providers. Added in v0.37. |
| `--oidc-use-pkce=false` | — | — | Override to disable PKCE explicitly when not supported by the provider. |

## Session flags

| Flag | Helm values key | Default | Description |
|---|---|---|---|
| `--session-ttl` | `config.sessionTTL` | — | Maximum session duration in seconds before re-authentication is required. |

## TLS flags

| Flag | Helm values key | Default | Description |
|---|---|---|---|
| `--tls-cert` | `config.tls.cert` | — | Path to TLS certificate for backend TLS termination. |
| `--tls-key` | `config.tls.key` | — | Path to TLS private key for backend TLS termination. |

## Example: minimal in-cluster invocation

This is what the Helm chart generates inside the container:

```bash
/headlamp/headlamp-server \
  --enable-helm \
  --watch-plugins-changes \
  --plugins-dir /headlamp/plugins \
  --base-url /headlamp \
  --port 4466
```

## Example: full OIDC invocation

```bash
/headlamp/headlamp-server \
  --enable-helm \
  --watch-plugins-changes \
  --oidc-client-id headlamp \
  --oidc-client-secret $(OIDC_CLIENT_SECRET) \
  --oidc-issuer-url https://dex.example.com \
  --oidc-scopes profile,email,groups \
  --oidc-use-pkce=true \
  --session-ttl 3600
```

## Helm chart values structure

```yaml
config:
  enableHelm: true
  watchPlugins: true
  pluginsDir: ""          # empty = use default
  baseURL: ""             # empty = served at /
  insecureSkipTlsVerify: false
  sessionTTL: 0           # 0 = no TTL
  oidc:
    clientID: ""
    clientSecret: ""
    issuerURL: ""
    scopes: ""
    usePKCE: false
  tls:
    cert: ""
    key: ""

service:
  type: ClusterIP
  port: 80

image:
  repository: ghcr.io/headlamp-k8s/headlamp
  tag: ""                 # default: chart appVersion
  pullPolicy: IfNotPresent

replicaCount: 1

pluginsManager:
  enabled: false
  baseImage: node:lts-alpine
  version: latest
  configContent: ""
```

See the [full values.yaml](https://github.com/kubernetes-sigs/headlamp/blob/main/charts/headlamp/values.yaml) for all available options with inline documentation.
