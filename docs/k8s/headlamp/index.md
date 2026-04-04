---
title: "Headlamp"
---

## What is Headlamp?

Headlamp is an **extensible, RBAC-aware Kubernetes web UI** that runs both in-cluster (as a pod you port-forward or expose via Ingress) and as a native desktop application (Electron). It is an official Kubernetes project under **SIG UI**, adopted by Oracle, Microsoft, Swisscom, and others.

What distinguishes it from alternatives like Lens or the vanilla Kubernetes Dashboard is its **plugin system**: you can add custom sidebar sections, routes, resource detail panels, app bar actions, and dashboards without forking the project. Flux, Backstage, Inspektor Gadget, Trivy, and cert-manager all have Headlamp plugins today.

## Key design principles

| Principle | Description |
|---|---|
| **Extensibility first** | Any UI customization should be achievable via a plugin |
| **RBAC-adaptive UI** | Action buttons appear only when the user's role permits them |
| **Multi-cluster** | One Headlamp instance can manage N clusters simultaneously |
| **Real-time** | Kubernetes watch events flow through a WebSocket multiplexer |
| **Security** | The browser never holds cluster credentials directly; all requests proxy through `headlamp-server` |

## Three runtime layers

Headlamp is composed of three layers that compose differently depending on deployment mode:

=== "headlamp-server (Go)"
    The central binary. Reads kubeconfigs, sets up per-cluster reverse proxies, serves the React SPA, discovers and serves plugin bundles, handles WebSocket multiplexing, and — when `--enable-helm` is set — runs the Helm API and authenticated service proxy.

=== "Frontend SPA (React/TypeScript)"
    Served by the backend as static assets, runs entirely in the browser. MUI components, Redux state, React Router. Loads plugin bundles at runtime and executes them in the same JS context. Communicates with the cluster exclusively through the backend proxy.

=== "Electron (Desktop)"
    Thin shell that embeds `headlamp-server` as a child process and opens a BrowserWindow pointing to it. Entry: `app/electron/main.ts`. Enables plugin management from Artifact Hub directly on the desktop.

## Quick start

```bash
# 1. Create a kind cluster
kind create cluster --name headlamp-dev

# 2. Install via Helm
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm install headlamp headlamp/headlamp \
  --namespace kube-system \
  --set config.enableHelm=true \
  --set config.watchPlugins=true

# 3. Get a token
kubectl create serviceaccount headlamp-admin -n kube-system
kubectl create clusterrolebinding headlamp-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:headlamp-admin
kubectl create token headlamp-admin -n kube-system --duration=8h

# 4. Access
kubectl port-forward -n kube-system service/headlamp 8080:80
# open http://localhost:8080 and paste the token
```

## This guide at a glance

### Understand

| Section | Audience |
|---|---|
| [Architecture](architecture.md) | Anyone — system design, domain clustering, hotspots |
| [Source Layout](source-layout.md) | Contributors, anyone reading the code |
| [Technical Debt & Danger Zones](../../../docs-internal/headlamp/technical-debt.md) | Architects, tech leads — the honest inventory |
| [Production Readiness](../../../docs-internal/headlamp/production-readiness.md) | Platform engineers — what works, what breaks at scale |

### Deploy

| Section | Audience |
|---|---|
| [Deploy on kind](kind-cluster.md) | Engineers evaluating or testing in-cluster features |
| [VKS Deployment Guide](../../../docs-internal/headlamp/vks-deployment.md) | VKS platform engineers — the complete production guide |
| [Authentication](authentication.md) | Platform engineers deploying for a team |
| [--enable-helm](enable-helm.md) | Anyone using App Catalog or Helm-aware features |
| [Service Proxy](service-proxy.md) | Plugin authors, App Catalog users |
| [App Catalog](app-catalog.md) | Platform engineers — includes silent failure analysis |
| [Server Flags](server-flags.md) | Quick reference, bookmark this |

### Extend

| Section | Audience |
|---|---|
| [Plugin Development](plugins/concepts.md) | Engineers building custom UI extensions |
| [Local Development](local-dev.md) | Contributors |
| [Contributing](contributing.md) | OSS contributors |
