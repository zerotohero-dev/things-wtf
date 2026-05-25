# Architecture

## Overview

Headlamp has three runtime layers: the Go backend (`headlamp-server`), the React SPA (frontend), and an optional Electron shell for the desktop app. They compose differently in each deployment mode but the request lifecycle is the same.

```
┌─────────────────────────────────────────────────────────────────┐
│  Browser (React SPA + loaded plugins)                           │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP / WebSocket
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  headlamp-server (Go)                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Cluster      │  │ Plugin       │  │ Helm API +           │  │
│  │ proxy        │  │ serving      │  │ /serviceproxy        │  │
│  └──────┬───────┘  └──────────────┘  └──────────┬───────────┘  │
└─────────┼───────────────────────────────────────┼──────────────┘
          │ kube-apiserver API                     │ in-cluster svc
          ▼                                        ▼
   Kubernetes API                           Service (Helm repo,
   (REST + Watch)                           catalog, etc.)
```

## Request lifecycle

Every user action in the UI travels the same path:

1. **Browser** initiates an HTTP or WebSocket request to `headlamp-server` (never directly to the cluster)
2. `headlamp-server` authenticates the request using the current token or OIDC session
3. The request is forwarded to the appropriate **cluster proxy**, which holds the actual cluster credentials
4. The Kubernetes API responds; the proxy returns the result to the browser

For **service proxy** requests (in-cluster services):

```
Browser → headlamp-server /serviceproxy/{ns}/{svc}/{path} → ClusterIP service
```

For **plugin assets**:

```
Browser → headlamp-server /plugins/{name}/main.js → static file from plugins dir
```

## WebSocket multiplexing

Browsers cap concurrent WebSocket connections at approximately 6. Headlamp solves this with a **multiplexer**:

- **One** WebSocket from the browser to `headlamp-server`
- `headlamp-server` fans out to **many** Watch connections against the Kubernetes API servers

This enables real-time updates across dozens of resource types simultaneously. The multiplexer logic lives in `backend/pkg/` and the frontend connects through a single shared channel rather than opening per-resource WebSockets.

## Plugin loading

```
headlamp-server startup
  └── scan plugins dir (~/.config/Headlamp/plugins/ by default)
        └── for each subdir with main.js:
              serve at /plugins/{name}/main.js

Browser startup
  └── fetch plugin list from /plugins/
        └── for each plugin:
              fetch /plugins/{name}/main.js
              execute in global JS context
              plugin calls registerXxx() functions
              registry takes effect immediately
```

!!! note "No sandboxing"
    Plugins run in the full application JavaScript context. They have access to the same React tree, Redux store, and shared dependencies as the core app. This is intentional — it enables deep integration — but means a poorly written plugin can affect the whole UI.

!!! info "Shared dependencies"
    React, Redux, MUI, React Router, Lodash, Monaco Editor, Iconify, and Notistack are provided by the host and automatically externalized by the plugin build toolchain. Do not bundle these in your plugin.

## Deployment modes

| Mode | Who runs headlamp-server | Plugin dir | kubeconfig source |
|---|---|---|---|
| **In-cluster** | Kubernetes pod | `/headlamp/plugins/` (or mounted volume) | In-cluster service account |
| **Desktop** | Electron child process | `~/.config/Headlamp/plugins/` | `~/.kube/config` |
| **Local dev** | `npm run backend:start` | `~/.config/Headlamp/plugins/` | `~/.kube/config` |

## Security model

- The browser **never** receives cluster credentials directly
- All cluster API calls are proxied through `headlamp-server`, which holds the token or mounts the service account
- RBAC is enforced cluster-side — Headlamp adapts the UI based on what the current token can do (e.g. no Edit button if the user lacks `update` permission on that resource)
- The service proxy requires an authenticated session; requests without a valid token are rejected before forwarding

---

## Domain Architecture (Code Intelligence Analysis)

Call-graph analysis of the codebase (12,547 symbols, 25,929 relationships) reveals internal structure that the official documentation obscures. The manual architecture describes 6 domains; static analysis finds **59 distinct clusters**.

### Backend: Clean Boundaries

The Go backend aligns well with its package structure. Each cluster maps to a distinct concern:

| Cluster | Symbols | Cohesion | What It Does |
|---------|---------|----------|--------------|
| **Cmd** | 335 | — | Server entry point, route registration, the 540-line `createHeadlampHandler()` |
| **Helm** | 55 | — | Helm SDK operations, release management, repository handling |
| **Kubeconfig** | 55 | — | Multi-cluster kubeconfig parsing and management |
| **Auth** | 48 | — | OIDC flow, token extraction, cookie chunking |
| **Stateless** | 41 | — | Dynamic cluster add/remove with TTL-based caching |

**Hidden coupling**: The service proxy (`backend/pkg/serviceproxy/`) has its own Go package boundary, but the graph absorbs it into the Cmd cluster because `createHeadlampHandler()` tightly couples route registration with handler creation. The package boundary is cosmetic — the real dependency flows through the 540-line handler constructor.

### Frontend: 9+ Clusters, Not "One Thing"

The official architecture describes "the frontend" as one layer. The graph tells a different story:

| Cluster | Symbols | Cohesion | What It Does |
|---------|---------|----------|--------------|
| **Resource** | 388 | — | K8s resource view components (**largest cluster in the codebase**) |
| **K8s** | 218 | — | K8s API client library (typed wrappers, hooks) |
| **V1** | 61 | 53% | Legacy API layer (low cohesion = transitional, being replaced) |
| **V2** | 29 | 71% | New API layer (higher cohesion = cleaner design) |
| **Settings** | 42 | — | Settings UI and configuration |
| **Plugin** | 46 | — | Plugin loader and registry |
| **Graph** | 30 | — | Visualization components |
| **Node** | 29 | — | Node-specific views |
| **Pod** | 27 | — | Pod-specific views |
| **App** | 27 | — | Application-level components |

The **Resource cluster (388 symbols)** is the largest and least cohesive — it's the "everything else" of the frontend. The **V1→V2 migration** is visible in the data: V1 has notably low cohesion (53%), suggesting it's a transitional layer being replaced by V2 (71% cohesion).

### Electron: Three Concerns, Not One

| Cluster | Symbols | What It Does |
|---------|---------|--------------|
| **Electron** | 84 | Core desktop app lifecycle, window management |
| **Mcp** | 42 | MCP client integration (AI assistant) — **its own domain** |
| **Commands** | 28 | Command execution subsystem (`runCommand()`) |

MCP is architecturally separate from Electron core. It has its own client, protocol handling, and IPC bridge. This matters because MCP is currently desktop-only — bringing it to in-cluster mode means extracting the Mcp cluster from its Electron dependency.

### Critical Hotspots

These symbols have the widest blast radius in the codebase. Changes here require the most careful review:

| Symbol | d=1 Callers | Execution Flows | Modules Affected |
|--------|-------------|-----------------|------------------|
| `createRouteURL` | 26 | 20 | 8 modules — **CRITICAL** |
| `createHeadlampHandler` | all backend routes | all backend flows | entire backend |
| `fetchAndExecutePlugins` | 1 | 4 | plugin loading pipeline |
| `registerSidebarEntry` | 1 in-repo (many external) | all plugin flows | all plugins |

### Boundary Violations

**Serviceproxy → Cmd absorption**: The service proxy package has its own Go package, but `RequestHandler` is registered as a route handler inside `createHeadlampHandler()`, making it structurally part of the server. Changes to service proxy behavior require understanding the Cmd cluster context.

**Plugin SDK → Frontend coupling**: The plugin SDK (`plugins/headlamp-plugin/`) copies files from `frontend/src/` into `lib/`. Every internal frontend refactor is a potential breaking change for the SDK. There is no versioned API boundary.
