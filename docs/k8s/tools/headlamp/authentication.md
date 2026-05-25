# Authentication

Headlamp supports two authentication methods: **service account tokens** (quick start, no config required) and **OIDC** (recommended for teams, enables all features).

## Service account tokens

This is the zero-config path. You create a token and paste it into the Headlamp UI once per session.

```bash
# create service account
kubectl create serviceaccount headlamp-admin -n kube-system

# bind a role (adjust ClusterRole to your security requirements)
kubectl create clusterrolebinding headlamp-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:headlamp-admin

# generate a token valid for 8 hours
kubectl create token headlamp-admin -n kube-system --duration=8h
```

Headlamp stores the token in the browser session. RBAC is enforced cluster-side; the UI adapts to show only permitted actions.

!!! warning "App Catalog limitation with token auth"
    Helm release listing in the App Catalog fails with non-OIDC (service account token) authentication due to a known bug in the service proxy Authorization header forwarding. Track [issue #4788](https://github.com/kubernetes-sigs/headlamp/issues/4788) for the fix. Use OIDC if you need full App Catalog functionality today.

## OIDC

OIDC is the recommended authentication method for shared deployments. It integrates with your existing identity provider (Dex, Keycloak, Azure Entra ID, Cognito, etc.) and enables features like per-user RBAC, group-based access, and auditable access logs.

### Helm configuration

```yaml title="values.yaml"
config:
  oidc:
    clientID: headlamp
    clientSecret: your-client-secret   # prefer mounting from a Secret
    issuerURL: https://dex.example.com
    scopes: groups,email
    usePKCE: true                      # recommended, v0.37+
```

Or as server flags:

```bash
./headlamp-server \
  --oidc-client-id headlamp \
  --oidc-client-secret your-secret \
  --oidc-issuer-url https://dex.example.com \
  --oidc-scopes groups,email \
  --oidc-use-pkce=true
```

### PKCE

`--oidc-use-pkce` enables [PKCE (Proof Key for Code Exchange)](https://oauth.net/2/pkce/), which prevents authorization code interception attacks. It is off by default for compatibility but should be enabled for any new deployment. Some providers (e.g. Azure Entra ID) require it.

Enable via Helm:

```yaml
config:
  oidc:
    usePKCE: true
```

Or via flag: `-oidc-use-pkce=true`

### Provider-specific tutorials

The Headlamp docs have step-by-step tutorials for common providers:

| Provider | Guide |
|---|---|
| Dex | [Tutorial: OIDC with Dex](https://headlamp.dev/docs/latest/installation/in-cluster/dex/) |
| Keycloak | [Tutorial: OIDC with Keycloak](https://headlamp.dev/docs/latest/installation/in-cluster/keycloak/) |
| Azure Entra ID | [Tutorial: Headlamp on AKS with Azure Entra-ID](https://headlamp.dev/docs/latest/installation/in-cluster/azure-entra-id/) |
| AWS Cognito | [Tutorial: Headlamp on EKS with Cognito](https://headlamp.dev/docs/latest/installation/in-cluster/eks/) |
| OpenUnison | [Tutorial: Authentication with OpenUnison](https://headlamp.dev/docs/latest/installation/in-cluster/openunison/) |

### Storing clientSecret securely

Do not put `clientSecret` in plain values.yaml committed to version control. Use a Kubernetes Secret reference instead:

```yaml title="values.yaml"
config:
  oidc:
    clientID: headlamp
    issuerURL: https://dex.example.com
    scopes: groups,email

extraEnv:
  - name: OIDC_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: headlamp-oidc
        key: clientSecret
```

```yaml title="headlamp-oidc-secret.yaml"
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-oidc
  namespace: kube-system
stringData:
  clientSecret: "your-actual-secret"
```

Then pass the flag referencing the env var: `--oidc-client-secret=$(OIDC_CLIENT_SECRET)` via the chart's `extraArgs`.

## Testing OIDC locally

The Headlamp repo ships a local Dex setup for developing and testing OIDC flows. See `docs/development/oidc.md` in the repo for exact steps. Required if you're working on: authentication flows, the service proxy, or anything that reads the logged-in user's identity.

## Session TTL

Control how long sessions remain valid before re-authentication:

```bash
--session-ttl 3600   # seconds; e.g. 1 hour
```

Via Helm: `config.sessionTTL: 3600`
