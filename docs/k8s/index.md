# Kubernetes Reference

A principal-engineer-depth reference covering primitives, extensibility, and community process.

## What's covered

| Section | Topics |
|---|---|
| **Foundations** | Mental model, control plane architecture, core primitives |
| **Workloads** | Deployments, StatefulSets, Services, Storage, RBAC, Scheduling |
| **Extensibility** | API machinery, CRDs, controllers, operators, admission control |
| **Community** | KEPs, SIGs, contributing |

## Three axioms

Everything in Kubernetes follows from three design principles:

**Level-triggered** — Controllers respond to *current state*, not event streams. A controller that misses an event will still converge on the next reconcile cycle.

**Optimistic concurrency** — Every object has a `resourceVersion` (an etcd revision). Writes must include it; stale writes return `409 Conflict`. No distributed locks.

**Edge-case safety** — Controllers use work queues with rate limiting + exponential backoff. Objects are re-enqueued on error; transient failures self-heal.

## Quick links

- [Mental model](foundations/mental-model.md) — start here if you're new to the reconciliation model
- [API machinery](extensibility/api-machinery.md) — GVK/GVR, informers, SSA, patch strategies
- [CRDs](extensibility/crds.md) — structural schema, CEL validation, multi-version
- [Controllers & informers](extensibility/controllers.md) — informer pipeline, work queue, reconcile loop
- [KEPs](community/keps.md) — how features enter and graduate in Kubernetes
