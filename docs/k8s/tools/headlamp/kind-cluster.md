# Deploy on a kind Cluster

kind (Kubernetes IN Docker) is the recommended way to test in-cluster features locally, including `--enable-helm`, the service proxy, and plugin deployment.

## Prerequisites

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm v3](https://helm.sh/docs/intro/install/)

## Step 1 — Create the cluster

```bash
kind create cluster --name headlamp-dev
kubectl cluster-info --context kind-headlamp-dev
```

## Step 2 — Add the Headlamp Helm repo

```bash
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
```

## Step 3 — Install with Helm

=== "Minimal (quick start)"
    ```bash
    helm install headlamp headlamp/headlamp \
      --namespace kube-system \
      --create-namespace \
      --set config.enableHelm=true \
      --set config.watchPlugins=true \
      --set service.type=ClusterIP
    ```

=== "With values.yaml (recommended)"
    ```yaml title="values-kind.yaml"
    config:
      enableHelm: true
      watchPlugins: true

    service:
      type: ClusterIP

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
    helm install headlamp headlamp/headlamp \
      --namespace kube-system \
      --create-namespace \
      -f values-kind.yaml
    ```

## Step 4 — Create a service account and token

```bash
# create the service account
kubectl create serviceaccount headlamp-admin -n kube-system

# bind cluster-admin (dev/eval only — scope this down for shared clusters)
kubectl create clusterrolebinding headlamp-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:headlamp-admin

# generate a short-lived token (copy this output)
kubectl create token headlamp-admin -n kube-system --duration=8h
```

!!! warning
    `cluster-admin` is convenient locally but never appropriate for shared or production clusters. Create a scoped `ClusterRole` covering only the resources your users need to interact with.

## Step 5 — Access via port-forward

```bash
kubectl port-forward -n kube-system service/headlamp 8080:80
```

Open [http://localhost:8080](http://localhost:8080), paste the token from step 4.

## Verify the deployment

```bash
# check the pod is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=headlamp

# check --enable-helm is active
kubectl logs -n kube-system deployment/headlamp | grep -i helm

# check plugins were installed (if pluginsManager is enabled)
kubectl logs -n kube-system -l app.kubernetes.io/component=plugins-manager
```

## Upgrade

```bash
helm upgrade headlamp headlamp/headlamp \
  --namespace kube-system \
  -f values-kind.yaml
```

To force plugin re-installation after a config change:

```bash
kubectl rollout restart deployment/headlamp -n kube-system
```

## Tear down

```bash
kind delete cluster --name headlamp-dev
```

## Minimal RBAC for production-like testing

Instead of `cluster-admin`, use this scoped role that covers typical Headlamp usage:

```yaml title="headlamp-rbac.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: headlamp-user
rules:
  - apiGroups: [""]
    resources:
      - pods
      - pods/log
      - pods/exec
      - services
      - endpoints
      - namespaces
      - nodes
      - configmaps
      - serviceaccounts
      - secrets           # needed for Helm release listing
      - persistentvolumes
      - persistentvolumeclaims
      - events
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
      - statefulsets
      - daemonsets
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["helm.toolkit.fluxcd.io"]    # if using Flux plugin
    resources: ["helmreleases"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-user-binding
subjects:
  - kind: ServiceAccount
    name: headlamp-admin
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: headlamp-user
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f headlamp-rbac.yaml
```
