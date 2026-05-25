# Kubernetes Operators — From Zero to Production

A complete reference covering the operator pattern, CRD design, controller-runtime
internals, kubebuilder workflows, advanced patterns, and production debugging.

Written for engineers who are **technical but new to the operator ecosystem** —
junior does not mean novice. You know Go, you know Kubernetes, but the operator
machinery has gaps. This guide fills them, from first principles to 2am triage.

---

## How to use this guide

The guide is structured as a progressive deep-dive across **21 sections** in five
groups. Work through them in order the first time. Once you know the concepts, use
the sidebar to jump directly to what you need.

=== "Foundations"

    Start here. These four sections establish the conceptual model everything else
    builds on — what operators *are*, how Kubernetes thinks about state, how the
    API is structured, and what CRDs actually do at the wire level.

=== "The Reconcile Loop"

    The core algorithm and the library that implements it. Understand these two
    sections and you can read any operator's source code.

=== "Building with kubebuilder"

    Hands-on. Walk through initializing a project, writing types with markers,
    building a production-quality controller, and wiring up watches.

=== "Advanced Patterns"

    Finalizers, owner references, status conditions, Server-Side Apply, webhooks.
    These are the patterns you need to get right for a production operator.

=== "Production"

    Leader election, observability, testing, lifecycle management, and the
    systematic 2am debugging playbook.

---

## Key concepts at a glance

| Concept | One-liner |
|---|---|
| **Operator** | Domain knowledge encoded as a Kubernetes controller |
| **CRD** | A schema that adds new vocabulary to the Kubernetes API |
| **Controller** | A control loop that watches objects and reconciles state |
| **Reconciler** | Your business logic — reads state, closes the gap, updates status |
| **Informer cache** | Local in-memory copy of watched objects — reads are fast but eventually consistent |
| **Work queue** | Deduplicates events; your reconciler always gets a key, never a delta |
| **Finalizer** | A string that blocks object deletion until your cleanup runs |
| **Owner reference** | Parent→child pointer enabling automatic garbage collection |
| **Status condition** | Standard `metav1.Condition` — the established way to communicate controller state |

---

## Prerequisites

- Comfortable with Go (structs, interfaces, goroutines, error handling)
- Basic Kubernetes usage (`kubectl get/apply/describe`, namespaces, RBAC)
- Familiarity with what Pods, Deployments, and Services are

You do **not** need prior operator experience. That's what this guide is for.

---

*Built for platform engineers managing Kubernetes infrastructure at scale.*
