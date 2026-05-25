# What is an Operator, Really?

An operator is a Kubernetes controller that manages a **custom resource**. A controller is a reconciliation loop that continuously drives the *actual state* of the world toward a *desired state*. That's the entire concept — but the devil is in every implementation detail.

The word "operator" implies *operational knowledge encoded as software*. Your operator should know how to deploy, configure, upgrade, backup, and recover your application — things that a human operator would do. If your controller just creates a Deployment and goes home, you've built a glorified Helm chart, not an operator.

---

## The Control Loop

```text
┌──────────────────────────────────────────────────────────────────────┐
│                    Kubernetes API Server                              │
│  ┌───────────────┐    Watch/List     ┌─────────────────────────┐    │
│  │  CustomResource│────────────────▶ │  Informer / Cache        │    │
│  │  (desired state│                  │  (local read replica)    │    │
│  └───────────────┘                  └────────────┬────────────┘    │
│                                                   │ enqueue key      │
└───────────────────────────────────────────────────┼──────────────────┘
                                                    ▼
                                    ┌──────────────────────┐
                                    │    Work Queue          │
                                    │  (deduplicated keys)  │
                                    └──────────┬───────────┘
                                               │ dequeue
                                               ▼
                                    ┌──────────────────────┐
                                    │  Reconcile(ctx, req)  │
                                    │  1. Fetch from cache  │
                                    │  2. Diff actual/desired│
                                    │  3. Act (create/update)│
                                    │  4. Update .status    │
                                    └──────────────────────┘
```

!!! info "Key Insight"
    The reconcile function is called with a **namespace/name key**, not an event. By the time it's called, you don't know what changed — and you shouldn't care. You fetch current state, compare, act. This is the "level-triggered" model, not edge-triggered. You react to *state*, not *transitions*.

---

## Level-Triggered vs Edge-Triggered

This distinction will save you weeks of debugging.

| Model | Behavior | Problem |
|-------|----------|---------|
| **Edge-triggered** | React to events: "a pod was deleted, do X" | Miss an event (restart, network blip) → stuck forever |
| **Level-triggered** | React to state: "observe that a pod is missing, create one" | Re-running reconcile always converges |

The Kubernetes controllers in the control plane (Deployment controller, ReplicaSet controller, etc.) are all level-triggered. Your operator should be too.

### What This Means in Practice

```go
// WRONG — edge-triggered thinking
func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // "something changed, let me figure out what and react"
    // This is fragile — you can't know what changed from req alone
}

// CORRECT — level-triggered thinking
func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 1. Fetch the full current state
    // 2. Compute what the world SHOULD look like
    // 3. Apply the diff
    // This is safe to run multiple times with identical result
}
```

---

## The Reconciler Interface

The entire framework contracts down to one interface:

```go
type Reconciler interface {
    Reconcile(context.Context, Request) (Result, error)
}
```

Where `Request` is just:

```go
type Request struct {
    types.NamespacedName  // namespace + name of the object
}
```

And `Result` controls what happens next:

```go
type Result struct {
    Requeue      bool
    RequeueAfter time.Duration
}
```

That's the entire public API surface you need to implement. Everything else — watches, cache, queues, leader election — is infrastructure that feeds into this.

---

## Why Not Just Use Helm?

| Capability | Helm | Operator |
|-----------|------|---------|
| Install | ✅ | ✅ |
| Upgrade | ✅ | ✅ |
| Drift detection | ❌ | ✅ Reconciles back |
| Self-healing | ❌ | ✅ Watches and restores |
| Operational runbooks | ❌ | ✅ Encoded in Go |
| Cross-resource orchestration | Limited | ✅ |
| Status feedback | ❌ | ✅ |
| Custom validation | Limited (hooks) | ✅ Webhooks + markers |

Use Helm for stateless applications with simple upgrade semantics. Use an operator when you need to encode *operational intelligence* that reacts to runtime state.
