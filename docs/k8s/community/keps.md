# KEPs — Kubernetes Enhancement Proposals

All significant changes to Kubernetes go through a KEP. They live at [`kubernetes/enhancements`](https://github.com/kubernetes/enhancements) under `keps/<sig-name>/<kep-number>-<title>/`. KEPs are the authoritative design record — if you want to understand *why* a feature works the way it does, read its KEP.

## KEP stages

| Stage | Feature gate default | Guarantees |
|---|---|---|
| **Provisional** | — | Idea accepted for design work; no implementation yet |
| **Implementable** | — | Design approved; implementation may begin |
| **Alpha** | `false` | Initial implementation; may change radically or be dropped |
| **Beta** | `true` | Implementation complete; e2e tests required; API likely stable |
| **Stable (GA)** | `true` (locked) | Feature gate eventually removed; full conformance testing |
| **Withdrawn** | — | Abandoned; may be superseded |

## KEP lifecycle

```
Idea → Provisional → Implementable → alpha (release N) → beta (N+1 or N+2) → stable (N+n)
```

Key gates:

- **Provisional → Implementable**: KEP README approved by SIG leads. Design is sound.
- **alpha → beta**: PRR (Production Readiness Review) approval required.
- **beta → stable**: PRR approval required. Conformance tests passing. Documented upgrade/downgrade path.

## KEP structure

Every KEP directory contains:

```
keps/sig-apps/3715-indexed-jobs/
├── kep.yaml        ← machine-readable metadata
├── README.md       ← the actual proposal
└── CHANGELOG.md    ← revision history
```

### kep.yaml

```yaml
title: Indexed Job
kep-number: 3715
authors: ["@ahg-g"]
owning-sig: sig-apps
participating-sigs: ["sig-scheduling"]
status: stable
stage: stable
latest-milestone: "v1.24"
milestone:
  alpha: "v1.21"
  beta: "v1.22"
  stable: "v1.24"
creation-date: "2021-01-15"
```

### README.md sections

Every KEP README covers:

**Summary** — one paragraph overview.

**Motivation** — why this change? What problem does it solve? User stories.

**Goals** — specific, measurable outcomes this KEP achieves.

**Non-Goals** — explicit scope boundary. What this KEP does *not* address.

**Proposal** — the API changes, user-facing behavior, example YAML.

**Design Details** — implementation approach, data structures, algorithms, API server behavior.

**Test Plan** — unit tests, integration tests, e2e tests, conformance tests.

**Graduation Criteria** — concrete requirements to move between stages. E.g., "Alpha: feature flag exists, basic e2e tests pass. Beta: PRR approved, upgrade/downgrade tested. Stable: no open bugs, conformance test added."

**Production Readiness Review** — checklist:
- Does the feature have a feature gate that defaults to disabled?
- What metrics are exposed?
- Are there alerts for anomalies?
- What happens on rollback? Is it safe to disable the feature mid-adoption?
- What is the scalability impact?
- Was the feature tested at scale (SIG Scalability)?

**Implementation History** — per-release summary of what was implemented.

**Drawbacks** — honest assessment of downsides.

**Alternatives** — other approaches considered and why they were rejected.

## Production Readiness Review (PRR)

The PRR team reviews KEPs at the alpha→beta and beta→stable transitions. Their checklist focuses on:

- **Observability**: is there a way to know if the feature is working? (metrics, events, conditions)
- **Disruptive rollback**: if the feature gate is disabled after adoption, what breaks? Is the cluster recoverable?
- **Scalability**: has SIG Scalability signed off? Does the feature add pressure to the API server, etcd, or scheduler?
- **Failure modes**: what happens if the new controller crashes? Does it degrade gracefully?
- **Upgrade/downgrade**: can a cluster upgrade to N and downgrade back to N-1 without data loss?

The PRR checklist is in `keps/NNNN/README.md` under the "Production Readiness Review Questionnaire" section.

## Finding KEPs

```bash
# Browse all KEPs for a SIG
ls kubernetes/enhancements/keps/sig-node/

# Search by feature name
grep -r "indexed job" kubernetes/enhancements/keps/ --include="kep.yaml" -l

# Find KEPs in a given milestone
grep -r 'stable: "v1.29"' kubernetes/enhancements/keps/ --include="kep.yaml" -l
```

Or use the [KEP tracker](https://github.com/kubernetes/enhancements/issues) — each KEP has a GitHub issue in the `kubernetes/enhancements` repo tagged with the SIG and milestone.

## Notable KEPs by area

| Area | KEP | What it introduced |
|---|---|---|
| API Machinery | [2887](https://github.com/kubernetes/enhancements/tree/master/keps/sig-api-machinery/2887-cel-admission-control) | ValidatingAdmissionPolicy (CEL) |
| API Machinery | [555](https://github.com/kubernetes/enhancements/tree/master/keps/sig-api-machinery/555-server-side-apply) | Server-Side Apply |
| Apps | [3715](https://github.com/kubernetes/enhancements/tree/master/keps/sig-apps/3715-indexed-jobs) | Indexed Jobs |
| Node | [2400](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/2400-node-swap) | Swap memory support |
| Node | [4381](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/4381-dra-structured-parameters) | Dynamic Resource Allocation |
| Network | [1453](https://github.com/kubernetes/enhancements/tree/master/keps/sig-network/1453-ingress-api) | Gateway API |
| Scheduling | [3022](https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/3022-min-domains-in-pod-topology-spread) | minDomains in TopologySpreadConstraints |
| Auth | [2784](https://github.com/kubernetes/enhancements/tree/master/keps/sig-auth/2784-csr-duration) | CSR Duration |
