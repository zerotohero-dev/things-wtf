# Source Layout

Clone from [github.com/kubernetes-sigs/headlamp](https://github.com/kubernetes-sigs/headlamp). The root `package.json` is the single entrypoint for all build, lint, and test operations across every component.

## Repository tree

```
headlamp/
├── backend/                        # headlamp-server binary (Go)
│   ├── cmd/
│   │   └── headlamp.go             # server entry point
│   └── pkg/
│       ├── cache/                  # Kubernetes API response cache
│       ├── config/                 # kubeconfig parsing and cluster management
│       ├── helm/                   # --enable-helm logic ← key for App Catalog
│       ├── kubeconfig/             # multi-cluster kubeconfig handling
│       ├── plugins/                # plugin discovery, validation, static serving
│       ├── portforward/            # port-forward support
│       └── utils/
│
├── frontend/                       # React SPA (TypeScript)
│   └── src/
│       ├── index.tsx               # SPA entry point
│       ├── components/             # MUI-based UI components
│       │   └── *.stories.tsx       # Storybook story per component
│       ├── K8s/                    # typed Kubernetes resource wrappers
│       ├── plugin/                 # plugin loader + registry API  ← read this
│       └── redux/                  # Redux store + slices
│
├── app/                            # Electron desktop app
│   └── electron/
│       └── main.ts                 # Electron entry point
│
├── plugins/
│   ├── headlamp-plugin/            # npx @kinvolk/headlamp-plugin create + build tooling
│   └── examples/                   # example plugins (good reading)
│
├── charts/
│   └── headlamp/
│       ├── Chart.yaml
│       └── values.yaml             # all chart knobs documented here
│
├── docs/                           # source for headlamp.dev documentation
└── package.json                    # root npm scripts (build/lint/test everything)
```

## Key files to read first

| File | Why |
|---|---|
| `backend/cmd/headlamp.go` | CLI flag definitions and server wiring — good first read for backend contributors |
| `backend/pkg/helm/` | All `--enable-helm` and service proxy logic — read this if working on App Catalog |
| `backend/pkg/plugins/` | How plugins are discovered and served — read before writing backend plugin-related code |
| `frontend/src/plugin/` | Plugin loader and registry API implementation — read before writing plugins |
| `frontend/src/K8s/` | Resource class definitions and hook implementations — read to understand K8s data flow |
| `charts/headlamp/values.yaml` | Every configurable option with inline documentation |
| `plugins/examples/` | Canonical plugin patterns — start here when building your first plugin |

## External repositories

These are in separate GitHub orgs:

| Repo | Contents |
|---|---|
| [headlamp-k8s/plugins](https://github.com/headlamp-k8s/plugins) | Flux, Backstage, Inspektor Gadget, App Catalog, Trivy, cert-manager plugins |
| [headlamp-k8s/headlamp-website](https://github.com/headlamp-k8s/headlamp-website) | headlamp.dev docs and blog |

## npm scripts entry point

The root `package.json` wires every component's build/lint/test through a consistent npm script interface. You never need to `cd backend && go build` manually.

```bash
# backend
npm run backend:build       # go build → backend/headlamp-server
npm run backend:start       # run in dev mode (insecure, uses local kubeconfig)
npm run backend:lint        # golangci-lint
npm run backend:lint:fix    # auto-fix what golangci-lint can
npm run backend:format      # gofmt + goimports
npm run backend:test        # go test ./...
npm run backend:coverage    # coverage to stdout

# frontend
npm run frontend:start      # Vite dev server (HMR, proxies /api/* to :4466)
npm run frontend:build      # production SPA build
npm run frontend:lint       # ESLint + TypeScript
npm run frontend:test       # Jest unit tests
npm run frontend:storybook  # Storybook component browser

# desktop
npm run start:app           # launch Electron app locally
npm run app:test            # Electron app tests
```
