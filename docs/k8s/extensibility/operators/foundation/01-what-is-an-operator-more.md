# 01 · What is an Operator?

The word "operator" comes from the human sysadmin who once managed complex
software — the person who knew how to install, upgrade, fail over, back up, and
debug a database or message broker. **An operator is that human knowledge, encoded
as software that runs inside Kubernetes.**

Formally: an operator is a Kubernetes controller that manages a *custom resource*
representing some application or infrastructure concern. Instead of you knowing
"to upgrade Kafka, you must do A, B, then C in order," the operator knows that and
acts on it automatically whenever the desired state changes.

---

## Without an operator vs. with one

| Without an operator | With an operator |
|---|---|
| Write YAML for every object manually | Declare the desired state in one custom resource |
| Upgrades are runbook exercises | Upgrades are a field change |
| Failure recovery is a human pager alert | Failure recovery is automated |
| *You* are the domain expert in the loop | Domain knowledge lives in the operator |

---

## Real-world examples you likely already use

- **cert-manager** — watches `Certificate` resources, calls ACME/Vault, creates and rotates Secrets
- **Flux Helm Controller** — watches `HelmRelease` resources, drives Helm installs and upgrades
- **SPIRE operator** — manages SPIRE server and agent lifecycle via CRDs
- **Prometheus Operator** — turns `ServiceMonitor` CRs into Prometheus scrape configs
- **External Secrets Operator** — syncs secrets from Vault, AWS SSM, etc. into Kubernetes Secrets

!!! info "Junior context"

    If you've ever run `kubectl apply -f helmrelease.yaml` and watched Flux install
    a Helm chart — you've already used an operator. Flux's source-controller,
    helm-controller, and kustomize-controller are all operators built with
    controller-runtime and scaffolded with kubebuilder. Everything in this guide
    is what's happening under that hood.

---

## The operator maturity model

Not every operator does everything. The community uses this maturity scale to
describe capability levels:

1. **Basic install** — automated deployment and configuration
2. **Seamless upgrades** — patch and minor version upgrades handled
3. **Full lifecycle** — backup, failure recovery, reconfiguration
4. **Deep insights** — metrics, alerts, workload analysis, tuning
5. **Auto-pilot** — horizontal/vertical scaling, auto-config, anomaly detection

Most platform operators sit at levels 2–3. Building to level 4+ requires deep
knowledge of the managed system.

---

## What an operator is *not*

An operator is not:

- A Helm chart (Helm has no control loop; it doesn't watch or self-heal)
- A CronJob that polls (operators react to events, not just time)
- A sidecar (operators run as separate controllers, not inside your workload)

The distinguishing property is the **continuous control loop**: an operator is
always watching, always reconciling. It doesn't run once and stop.
