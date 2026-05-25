# Config & Secrets

## ConfigMap

Arbitrary non-sensitive configuration data. Max size 1MiB (etcd value limit).

```yaml
apiVersion: v1
kind: ConfigMap
data:
  APP_ENV: production
  LOG_LEVEL: info
  config.yaml: |
    server:
      port: 8080
      timeout: 30s
binaryData:
  logo.png: <base64>   # for binary content
```

### Consumption patterns

**Environment variables (individual):**

```yaml
env:
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: myapp-config
      key: APP_ENV
      optional: false   # pod fails to start if key is missing
```

**Environment variables (bulk):**

```yaml
envFrom:
- configMapRef:
    name: myapp-config
    optional: false
```

**Volume mount:**

```yaml
volumes:
- name: config
  configMap:
    name: myapp-config
    defaultMode: 0644
    items:                    # optional: select specific keys
    - key: config.yaml
      path: app/config.yaml
```

### Update behavior

| Consumption method | Update behavior |
|---|---|
| Volume mount | Updated automatically, ~60s kubelet sync delay. Watch the file in the app. |
| `envFrom` / `env.valueFrom` | **Not updated** until pod restarts. ConfigMap change doesn't trigger restart. |

!!! note
    Use a sidecar or init container to detect ConfigMap changes and signal the main process (SIGHUP, etc.) if you need live reload with env vars.

## Secret

Same structure as ConfigMap, but values are base64-encoded and treated with additional care:

- Not sent to nodes that don't need them (pods that don't mount them)
- Stored in tmpfs on nodes (not written to disk)
- Auditable separately from configmaps

```yaml
apiVersion: v1
kind: Secret
type: Opaque
data:
  password: dXBlcnNlY3JldA==   # base64("supersecret")
stringData:
  api-key: "my-plaintext-key"   # auto-base64-encoded on create
```

!!! warning "base64 is not encryption"
    `kubectl get secret mysecret -o jsonpath='{.data.password}' | base64 -d` — readable by anyone with GET on the Secret. Enable KMS envelope encryption for encryption at rest.

### Secret types

| Type | Use |
|---|---|
| `Opaque` | Arbitrary data. Default. |
| `kubernetes.io/tls` | TLS cert + key. Required fields: `tls.crt`, `tls.key`. |
| `kubernetes.io/dockerconfigjson` | Image pull secret. Used via `spec.imagePullSecrets`. |
| `kubernetes.io/service-account-token` | Bound SA token. Rarely created manually since 1.24. |
| `kubernetes.io/ssh-auth` | SSH key. Required field: `ssh-privatekey`. |
| `kubernetes.io/basic-auth` | Username/password. Required: `username`, `password`. |
| `bootstrap.kubernetes.io/token` | Node bootstrap token. |

### Encryption at rest

Enable KMS envelope encryption in the API server's `EncryptionConfiguration`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: aws-kms
      endpoint: unix:///var/run/kmsplugin/socket.sock
  - identity: {}   # fallback for migration; remove after re-encrypting all secrets
```

After enabling, rotate all existing secrets by re-applying them (they're stored unencrypted until touched).

### External secrets management

For production, prefer pulling secrets from an external store rather than storing them in Kubernetes Secrets:

- **External Secrets Operator (ESO)** — syncs from AWS Secrets Manager, Vault, GCP Secret Manager, etc. into Kubernetes Secrets. Supports `ExternalSecret` and `ClusterExternalSecret` CRDs.
- **Secrets Store CSI Driver** — mounts secrets directly as volumes from external stores, bypassing Kubernetes Secrets entirely. Supports sync to env vars via `secretObjects`.
- **Vault Agent Injector** — mutating webhook that injects a Vault agent sidecar to fetch and renew secrets.

## Projected volumes

Combines multiple sources into a single mount:

```yaml
volumes:
- name: projected
  projected:
    sources:
    - serviceAccountToken:
        audience: my-service
        expirationSeconds: 3600
        path: token
    - configMap:
        name: myapp-config
        items: [{key: config.yaml, path: config.yaml}]
    - secret:
        name: myapp-tls
        items: [{key: tls.crt, path: tls/cert.pem}]
    - downwardAPI:
        items:
        - path: labels
          fieldRef: {fieldPath: metadata.labels}
        - path: cpu-limit
          resourceFieldRef: {resource: limits.cpu, containerName: app}
```

### ServiceAccountToken rotation

The serviceAccountToken source in a projected volume is automatically rotated by the kubelet. The kubelet requests a new token from the API server before the current one expires — the file on disk is updated transparently without pod restart. This is the preferred way to inject SA tokens since 1.22 (legacy auto-mounted tokens in `/var/run/secrets/kubernetes.io/serviceaccount/` are being phased out).

## LimitRange

Sets default requests/limits and enforces min/max per namespace:

```yaml
apiVersion: v1
kind: LimitRange
spec:
  limits:
  - type: Container
    default:          {cpu: "500m", memory: "256Mi"}   # applied if not set
    defaultRequest:   {cpu: "100m", memory: "128Mi"}
    max:              {cpu: "2",    memory: "4Gi"}
    min:              {cpu: "50m",  memory: "64Mi"}
  - type: PersistentVolumeClaim
    max: {storage: 50Gi}
    min: {storage: 1Gi}
```

## ResourceQuota

Caps total resource consumption per namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    count/pods: "50"
    count/services.loadbalancers: "3"
    persistentvolumeclaims: "20"
    requests.storage: 500Gi
```

When a ResourceQuota is active in a namespace, all pods must have requests and limits set — otherwise the API server rejects them. Pair with a LimitRange that sets defaults to avoid this footgun.
