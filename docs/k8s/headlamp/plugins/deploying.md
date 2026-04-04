# Deploying Plugins In-Cluster

There are three deployment strategies. Choose based on how often you update the plugin and whether you need to source it from Artifact Hub or a private registry.

## Strategy A: pluginsManager (recommended)

The Headlamp Helm chart runs an optional **sidecar container** (based on `node:lts-alpine`) that installs plugins from Artifact Hub or a custom registry into a shared `emptyDir` volume. The main Headlamp container serves them. With `watchPlugins: true`, plugin changes propagate without restarting the pod.

```yaml title="values.yaml"
config:
  watchPlugins: true        # reload plugins when directory changes

pluginsManager:
  enabled: true
  baseImage: node:lts-alpine   # override with your registry proxy if needed
  configContent: |
    plugins:
      - name: flux
        source: https://artifacthub.io/packages/headlamp/headlamp-plugins/headlamp_flux
        version: latest
      - name: app-catalog
        source: https://artifacthub.io/packages/headlamp/headlamp-plugins/headlamp_app_catalog
        version: latest
      - name: my-internal-plugin
        source: https://registry.internal/headlamp/my-plugin
        version: 0.2.0
    installOptions:
      parallel: true
      maxConcurrent: 3
```

```bash
helm upgrade headlamp headlamp/headlamp \
  --namespace kube-system \
  -f values.yaml
```

To update a plugin version, bump the `version` field and re-run `helm upgrade`. With `watchPlugins: true`, changes propagate without a pod restart.

!!! tip "Air-gapped clusters"
    For clusters without internet access, set `baseImage` to an image in your internal registry, and use an internal `source` URL instead of `artifacthub.io`.

## Strategy B: initContainer + emptyDir

Build your plugin bundle into a minimal container image. Use an `initContainer` to copy it into a shared `emptyDir` that the Headlamp container reads as its plugins directory. Best for plugins with infrequent updates where you want full control over the image.

**Step 1: Dockerfile for your plugin**

```dockerfile title="Dockerfile"
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY src/ src/
RUN npm run build

FROM alpine:3.19
# copy the built bundle into a predictable location
COPY --from=build /app/dist/main.js /plugin/main.js
```

```bash
docker build -t registry.internal/my-headlamp-plugin:0.2.0 .
docker push registry.internal/my-headlamp-plugin:0.2.0
```

**Step 2: initContainer in Headlamp deployment**

Use the Helm chart's `initContainers` and `extraVolumes`/`extraVolumeMounts` values:

```yaml title="values.yaml"
extraVolumes:
  - name: my-plugin
    emptyDir: {}

extraVolumeMounts:
  - name: my-plugin
    mountPath: /headlamp/plugins/my-plugin

initContainers:
  - name: install-my-plugin
    image: registry.internal/my-headlamp-plugin:0.2.0
    command: ["cp", "-r", "/plugin/.", "/headlamp/plugins/my-plugin/"]
    volumeMounts:
      - name: my-plugin
        mountPath: /headlamp/plugins/my-plugin
```

The Headlamp container will serve `/headlamp/plugins/my-plugin/main.js` automatically.

## Strategy C: Bake into the Headlamp image

Build a custom Headlamp image that includes your plugin bundle. Simplest to operate but requires rebuilding the image for every plugin update.

```dockerfile title="Dockerfile"
FROM ghcr.io/headlamp-k8s/headlamp:v0.37.0

# copy plugin bundle to the default plugins directory
COPY dist/main.js /headlamp/plugins/my-plugin/main.js
```

```yaml title="values.yaml"
image:
  repository: registry.internal/my-headlamp
  tag: "0.37.0-myplugin-0.2.0"
  pullPolicy: Always
```

## Publishing to Artifact Hub

Publishing makes your plugin discoverable and installable by anyone using Headlamp. See the [official publishing guide](https://headlamp.dev/docs/latest/development/plugins/publishing) for the full Artifact Hub submission process.

The short version:

1. Build and package: `npm run build && npm run package`
2. Host the tarball at a stable URL (GitHub Releases is common)
3. Create an `artifacthub-pkg.yml` manifest pointing at the tarball
4. Submit to Artifact Hub via their [CLI or web form](https://artifacthub.io/docs/topics/repositories/headlamp-plugins/)

## Plugin directory layout

Regardless of strategy, the expected on-disk layout is:

```
{plugins-dir}/
└── my-plugin/
    └── main.js
```

Any additional assets (images, WASM, etc.) can be placed in the same directory and are served at `/plugins/my-plugin/{asset}`.

## Verifying installation

```bash
# from outside the cluster
curl http://localhost:8080/plugins/my-plugin/main.js | head -5
# should return your plugin bundle

# from inside the cluster
kubectl exec -n kube-system deployment/headlamp -- ls /headlamp/plugins/
```
