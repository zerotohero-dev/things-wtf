# Kubernetes Operators: A Practitioner's Field Manual

!!! abstract "What this is"
    A deep-dive into building **production-grade** Kubernetes operators using `kubebuilder`, `controller-gen`, and `kind`. Real reconciliation patterns, real gotchas, real cache semantics — not toy examples.

---

## Toolchain

| Tool | Purpose |
|------|---------|
| `kubebuilder v4` | Project scaffolding, CRD generation |
| `controller-gen` | Generates CRD YAML and RBAC from Go markers |
| `controller-runtime` | The reconciler framework everything is built on |
| `kind` | Local Kubernetes cluster for development |

No Operator SDK. We want to understand every layer.

---

## What You'll Learn

=== "Foundation"
    - The control loop — level-triggered vs edge-triggered
    - `kubebuilder` project scaffold and structure
    - CRD design and `controller-gen` markers in depth

=== "Reconciliation"
    - Idempotency contracts and why they matter
    - Requeue strategies — when each return value is right
    - Status, conditions, and `ObservedGeneration`
    - Finalizers, deletion lifecycle, and deadlocks
    - Ownership, GC, and owner references

=== "Filtering & Events"
    - Predicates — filtering what triggers reconcile
    - Watching owned vs unowned resources
    - `MapFunc` watches with field indexers

=== "Cache & State"
    - How informers actually work (Reflector → DeltaQueue → Store)
    - The four critical cache gotchas
    - Field indexers for efficient lookups
    - Namespace and label-selector scoping

=== "Advanced"
    - Rate limiting and work queue tuning
    - Leader election configuration
    - RBAC marker patterns
    - Full WebApp operator implementation
    - Testing with `envtest`
    - Production readiness checklist

---

## Philosophy

> An operator is a Kubernetes controller that manages a custom resource. A controller is a reconciliation loop that continuously drives the **actual state** toward a **desired state**.

The reconcile function is called with a **namespace/name key**, not an event. By the time it's called, you don't know what changed — and you shouldn't care. You fetch current state, compare, act. This is the **level-triggered** model.

| Model | Approach | Resilience |
|-------|----------|-----------|
| Edge-triggered | React to events | Fragile — missed events cause inconsistency |
| **Level-triggered** | **React to observed state** | **Resilient — restarts and missed events are safe** |

---

## Prerequisites

```bash
# Go 1.21+
go version

# kubebuilder v4
kubebuilder version

# kind
kind version

# controller-gen (bundled with kubebuilder, or standalone)
controller-gen --version
```
