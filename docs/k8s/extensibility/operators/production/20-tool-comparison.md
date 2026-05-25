# 20 · Tool Comparison

## kubebuilder vs. Operator SDK vs. raw controller-runtime

The important thing to understand upfront: **Operator SDK is kubebuilder with
extra features for OLM**. The generated code is nearly identical. Learning
kubebuilder means you already understand 90% of Operator SDK.

| Dimension | kubebuilder | Operator SDK | controller-runtime (raw) | Kopf (Python) |
|---|---|---|---|---|
| Core library | controller-runtime | controller-runtime | itself | kubernetes Python client |
| Scaffolding | Full | Full + Ansible/Helm types | None | Partial |
| Code generation | controller-gen markers → YAML | Same, delegates to controller-gen | Run controller-gen manually | N/A |
| OLM / OperatorHub support | Manual | First-class CSV generation | Manual | N/A |
| Ansible / Helm operators | No | Yes — no Go needed | No | No |
| Community alignment | Kubernetes SIG API Machinery | Red Hat / OpenShift | Same upstream | Independent |
| Upgrade story | Re-run scaffold, compare diff | Similar | Manage module deps yourself | pip update |
| Best for | Go operators, platform teams, CNCF alignment | ISV products targeting OpenShift/OLM | Teams wanting full project control | Rapid prototyping, Python shops |

---

## When to use each

**kubebuilder** — the default choice for new Go operators on any Kubernetes
distribution. It's the upstream standard maintained by SIG API Machinery. If you
want to contribute to the CNCF ecosystem or need good documentation and examples,
start here.

**Operator SDK** — use *only* if you're targeting OLM (Operator Lifecycle
Manager) or OperatorHub, or if you need Ansible/Helm operators without writing Go.
OLM is the standard in OpenShift environments. If you're not going to
OperatorHub, the extra complexity of Operator SDK adds no value.

**Raw controller-runtime** — appropriate if you're working in an existing project
that predate kubebuilder (like SPIKE or VSecM), or if your project structure
has outgrown the scaffold. Most large CNCF operators (Flux, Argo, cert-manager,
Crossplane) use raw controller-runtime with their own project structures. When you
read their source, every pattern in this guide will be recognizable.

**Kopf** — skip for production. Python's operational overhead, lack of Go's static
typing for Kubernetes object structs, and the ecosystem's Go-centricity make it a
poor choice for anything beyond quick prototyping.

---

## The generated code comparison

Both kubebuilder and Operator SDK generate the same `SetupWithManager` and
`Reconcile` patterns because they both use controller-runtime. Here's what differs:

| File / concept | kubebuilder | Operator SDK |
|---|---|---|
| `cmd/main.go` | Nearly identical | Nearly identical |
| Controller | Identical pattern | Identical pattern |
| Types + markers | Identical | Identical |
| `config/` manifests | Kustomize-based | Kustomize-based |
| OLM bundle | Not generated | `make bundle` generates CSV |
| Scorecard | Not included | Included (tests your operator against OLM requirements) |
| Ansible/Helm | Not supported | `operator-sdk init --plugins=ansible` |

---

## Upgrading the scaffold

Neither kubebuilder nor Operator SDK provides automated upgrades of existing
projects. The process is:

1. Run the scaffold commands for the new version in a fresh directory
2. `diff` the generated files against your current project
3. Manually merge changes, keeping your business logic, adopting framework changes

Tools like `kubebuilder alpha generate` (experimental) aim to help, but manual
review is still required. Pin your kubebuilder version in your project's
`Makefile` and upgrade deliberately.
