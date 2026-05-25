# K8s Operators: Hands-On Study Plan

> One week, focused. Go background assumed.

---

## Core Concepts You Must Own

1. **CRDs** — Custom Resource Definitions. Your operator's API surface. Understand OpenAPI validation, versioning (v1alpha1 → v1), and conversion webhooks.
2. **Reconciliation loop** — the heart of every operator. `Reconcile(ctx, req)` runs whenever desired state ≠ actual state. Must be idempotent. This is where most bugs live.
3. **Informers + work queue** — how the controller watches resources without polling the API server constantly. kubebuilder abstracts this but you need to know what's underneath.
4. **Finalizers** — how you prevent a resource from being deleted before you clean up external state. Critical for operators that touch things outside k8s.
5. **Status subresource** — how you report operator progress back to the user (`conditions`, `observedGeneration`, `phase`). Separate from spec, separate RBAC.
6. **Owner references** — how child resources (Deployments, Services, etc.) get garbage collected when the parent CR is deleted.
7. **Admission webhooks** — validating (reject bad CRs) and mutating (set defaults). Not optional for production operators.
8. **Leader election** — running multiple operator replicas safely. Free with controller-runtime, but understand why it exists.

---

## The Project: `SecretReplicator` Operator

Simple enough to finish in a few days, complex enough to touch all the real concepts.

**CRD: `SecretReplication`**
> "Replicate this secret from namespace A to namespaces matching label X"

**What it exercises:**
- Reconciler: watch the CR + the source Secret, create/update copies in target namespaces
- Finalizer: clean up copies when the CR is deleted
- Status: report which namespaces are synced, which failed
- Validating webhook: reject if source secret doesn't exist
- RBAC: principle of least privilege — only read the source, only write in target namespaces

**Why this project:** Secret replication is a real, unsolved pain in k8s. You'll hit namespace-scoped vs cluster-scoped RBAC, multi-resource watching, and the garbage collection problem. Actually useful in production.

**Alternative (given your SPIFFE background):** A `WorkloadIdentity` operator that auto-registers k8s pods with a SPIRE server based on annotations. More complex, directly relevant to your expertise, more impressive to show.

---

## Tooling

**Use kubebuilder, not operator-sdk.**
operator-sdk wraps kubebuilder and adds Ansible/Helm support you don't need. kubebuilder directly — cleaner scaffolding, you learn the actual controller-runtime API.

```bash
# Setup
brew install kubebuilder
kubebuilder init --domain yourdomain.io --repo github.com/you/secret-replicator
kubebuilder create api --group sync --version v1alpha1 --kind SecretReplication
```

**Local cluster:** `kind` (Kubernetes in Docker) — faster than minikube, no VM overhead.

---

## Week Plan (~2-3 focused hours/day)

| Day | Focus |
|-----|-------|
| 1 | k8s API machinery fundamentals: informers, work queues, `client-go` under the hood. Read the controller-runtime source for `Reconciler`. |
| 2 | kubebuilder scaffold → CRD → deploy to kind. Make `kubectl get secretreplications` work. |
| 3 | Write the reconciler: happy path only. Secret exists, copies appear in target namespaces. |
| 4 | Edge cases: source secret deleted, target namespace disappears, finalizer for cleanup. |
| 5 | Status conditions + observedGeneration. Validating webhook. |
| 6 | RBAC audit, e2e tests with envtest, Helm chart for deployment. |
| 7 | Buffer / polish / write a short doc explaining design decisions (good interview material). |

---

## What to Read

- [kubebuilder book](https://book.kubebuilder.io/) — actually good, read chapters 1-3 before touching code
- [Writing a Controller](https://github.com/kubernetes/sample-controller) — the low-level version, read once to understand what kubebuilder hides
- [Kubernetes API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md) — spec/status split, conditions format, the stuff that makes your operator feel "native"

---

## What Interviewers Actually Test

- Do you understand why reconciliation must be idempotent?
- What happens if your operator crashes mid-reconcile?
- How do you handle rate limiting / exponential backoff on errors?
- What's the difference between `Requeue` and `RequeueAfter`?
- How would you version a CRD and write a conversion webhook?

Build the project, make it break, fix it — you'll have answers from experience, not memorization.
