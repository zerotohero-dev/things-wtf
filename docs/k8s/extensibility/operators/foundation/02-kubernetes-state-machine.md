# 02 · Kubernetes as a State Machine

The most important mental model in Kubernetes is this: **the entire cluster is a
distributed state machine.** Every component — the scheduler, the kubelet, the
controller-manager, your operator — is just a reconciler that reads the current
state of the world and drives it toward the desired state.

---

## etcd: the ground truth

`etcd` is a strongly-consistent distributed key-value store. It is the *only*
source of truth in Kubernetes. Every object you've ever `kubectl apply`'d lives
in etcd. The API server is mostly a smart HTTP proxy that validates, authenticates,
and serializes writes to etcd, and serves reads from it (with caching).

!!! info "What 'strongly consistent' means"

    Unlike eventually-consistent databases (like many NoSQL stores), etcd guarantees
    that once a write is acknowledged, every subsequent read will see that write —
    even from a different etcd member. This is why Kubernetes can make reliable
    scheduling decisions: when the scheduler marks a pod as bound to a node, every
    other component immediately sees that binding. This property is provided by the
    **Raft consensus algorithm** that etcd uses internally.

---

## Watch: the pub/sub backbone

etcd supports a **watch** operation: a long-lived HTTP/2 stream where the API
server gets notified whenever any object in a given key prefix changes. This is
how all controllers stay up to date without polling.

When you run `kubectl get pods -w`, you're using this exact mechanism. A controller
sets up a watch on its resource types and receives a stream of `ADDED`, `MODIFIED`,
and `DELETED` events.

```
kubectl apply     API server        etcd           Controller
     │                │               │                │
     │── write ──────>│               │                │
     │                │── persist ───>│                │
     │                │               │── notify ─────>│
     │                │               │   (watch)      │
```

---

## Spec vs. Status — the two halves of every object

Every Kubernetes object is divided into two logical sections:

- **Spec** — *desired state*. Written by users and tools. "I want 3 replicas of this Pod."
- **Status** — *observed state*. Written by controllers. "I see 2 replicas running, 1 pending."

This separation is fundamental. Users never write status directly (the status
subresource enforces this at the API level). Controllers never write spec — they
only read it and act on the gap between spec and status.

---

## Level-triggering vs. edge-triggering

This is one of the most important concepts for understanding why controllers are
designed the way they are.

- **Edge-triggered**: react to *events*. "Something changed to X."
- **Level-triggered**: react to *states*. "The current state is X. Is that right? If not, fix it."

Kubernetes controllers are **level-triggered**. A controller doesn't care *how*
a pod became missing. It sees "there are 2 pods, I need 3" and creates one. This
property makes controllers naturally self-healing and resilient to missed events.

!!! tip "The thermostat analogy"

    A thermostat is the perfect level-triggered controller. It doesn't care why the
    room is cold — someone opened a window, the furnace tripped, whatever. It reads
    current temperature, compares to desired temperature, and acts. Your
    `Reconcile()` function *is* a thermostat: read actual state, compare to desired,
    act on the gap. It runs every time something might have changed, and must always
    be safe to run.

---

## The full flow

```
User                 API Server            etcd              Controller
 │                       │                  │                    │
 │── kubectl apply ─────>│                  │                    │
 │                       │── validate ──────│                    │
 │                       │── persist ──────>│                    │
 │                       │                  │── watch event ────>│
 │                       │                  │                    │── Reconcile()
 │                       │<─── r.Status().Patch() ──────────────│
 │                       │── persist ──────>│                    │
 │<── kubectl get ───────│                  │                    │
```

Notice: the controller never receives the user's original intent directly. It
receives a watch event, fetches the current object, and figures out what to do.
This indirection is intentional and is what makes the system resilient.
