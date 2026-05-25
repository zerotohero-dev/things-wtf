# Local Development

## Prerequisites

| Requirement | Version |
|---|---|
| Go | ≥ 1.21 |
| Node.js | ≥ 20.18.1 (npm included) |
| `~/.kube/config` | Any reachable cluster (kind works great) |

## Bootstrap

```bash
# clone
git clone https://github.com/kubernetes-sigs/headlamp
cd headlamp

# build the Go backend binary
npm run backend:build
```

## Run the dev environment

You need two terminals:

=== "Terminal 1 — Backend"
    ```bash
    npm run backend:start
    # listening on :4466
    # reads ~/.kube/config, insecure mode — do not use in production
    ```

=== "Terminal 2 — Frontend"
    ```bash
    npm run frontend:start
    # Vite dev server on :3000
    # proxies /api/* and /clusters/* to :4466 automatically
    ```

Open [http://localhost:3000](http://localhost:3000).

Changes to `frontend/src/` hot-reload instantly. Changes to Go files require a rebuild:

```bash
npm run backend:build && npm run backend:start
```

## Running with a specific cluster

```bash
# point to a specific kubeconfig
KUBECONFIG=~/.kube/my-cluster.yaml npm run backend:start

# or multiple kubeconfigs (colon-separated)
KUBECONFIG=~/.kube/dev.yaml:~/.kube/staging.yaml npm run backend:start
```

## Running the desktop app locally

```bash
npm run start:app
# builds backend + frontend, launches Electron window
```

## All npm scripts

| Script | Description |
|---|---|
| `npm run backend:build` | Compile the Go binary to `backend/headlamp-server` |
| `npm run backend:start` | Run backend in insecure dev mode |
| `npm run backend:lint` | golangci-lint |
| `npm run backend:lint:fix` | Auto-fix lint issues |
| `npm run backend:format` | gofmt + goimports |
| `npm run backend:test` | Go unit tests |
| `npm run backend:coverage` | Coverage report to stdout |
| `npm run backend:coverage:html` | Coverage report in browser |
| `npm run frontend:start` | Vite dev server with HMR |
| `npm run frontend:build` | Production SPA build |
| `npm run frontend:lint` | ESLint + TypeScript checks |
| `npm run frontend:test` | Jest unit tests |
| `npm run frontend:storybook` | Component browser |
| `npm run start:app` | Launch Electron desktop app |

## Code quality

Run these before every commit:

```bash
# backend
npm run backend:lint
npm run backend:format

# frontend
npm run frontend:lint
```

!!! tip
    Set up a git pre-push hook that runs lint and test automatically. CI will reject PRs with lint failures — catching them locally is faster.

## Developing against a specific Headlamp version

If you need to develop against a tag rather than `main`:

```bash
git fetch --tags
git checkout v0.37.0
npm run backend:build
npm run frontend:start
```

## Common issues

**Backend won't start: `permission denied` on kubeconfig**

```bash
chmod 600 ~/.kube/config
```

**Frontend shows empty cluster list**

Make sure `npm run backend:start` is running in another terminal. The Vite proxy requires the backend to be up.

**Go module download errors behind a proxy**

```bash
export GOPROXY=https://proxy.golang.org,direct
export GONOSUMDB="*"
npm run backend:build
```
