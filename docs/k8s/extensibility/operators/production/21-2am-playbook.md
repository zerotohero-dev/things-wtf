# 21 · The 2am Playbook

When an operator is misbehaving at 2am, work through this systematic triage.
Each step either confirms a hypothesis or eliminates it. Don't skip steps.

---

## Step 1 — Is the operator running? Who is the leader?

```bash
kubectl -n spike-system get pods -l app=spike-operator
kubectl -n spike-system get lease spike-operator-leader -o yaml
```

What to look for:

- All pods in `Running` state? If not, look at pod events and describe output
- `spec.renewTime` on the lease — if stale by more than `leaseDuration`, the leader is dead/frozen and nothing is reconciling
- `spec.holderIdentity` — matches a running pod? If the holder pod is gone, standbys should have taken over; if they haven't, check their logs

---

## Step 2 — Check reconcile metrics: error rate and work queue depth

```bash
kubectl -n spike-system port-forward deploy/spike-operator 8080:8080 &
curl -s localhost:8080/metrics | grep -E \
  'controller_runtime_(reconcile_total|active_workers|reconcile_time)'
```

Interpret:

- **`reconcile_total{result="error"}` increasing** → read logs, something is broken
- **`active_workers` pinned at `MaxConcurrentReconciles`** → goroutine leak or a blocking `Reconcile()` call
- **`reconcile_time_seconds` p99 high** → slow external calls (SPIRE gRPC, Vault reads); check network or external system health
- **`reconcile_total` = 0 for an object you expect to reconcile** → watch predicate filtering too aggressively, or `SetupWithManager` missing a watch

---

## Step 3 — Look at the object's conditions and generation

```bash
kubectl get spikeconfig my-config -o json | jq '{
  generation:         .metadata.generation,
  observedGeneration: .status.observedGeneration,
  phase:              .status.phase,
  conditions:         .status.conditions
}'
```

Interpret:

- **`generation > observedGeneration`** → reconciler hasn't processed the latest spec. Check if it's running, queued, or erroring
- **`phase: "Failed"` + condition message** → read the `message` field — it usually tells you exactly what failed
- **Conditions missing entirely** → reconciler is crashing before it reaches the status update. Look at crash logs

---

## Step 4 — Check events on the object

```bash
kubectl describe spikeconfig my-config
```

The **Events** section shows what the controller emitted via `r.Recorder.Event()`.
It also shows admission webhook rejections that prevented updates from being
applied.

---

## Step 5 — Is the object stuck Terminating?

```bash
kubectl get spikeconfig my-config \
  -o jsonpath='DeletionTimestamp={.metadata.deletionTimestamp} Finalizers={.metadata.finalizers}'
```

If `DeletionTimestamp` is set and finalizers are present, the controller must run
its cleanup. If the controller is broken, the object stays stuck forever.

```bash
# Only after manually verifying external cleanup or accepting the leaked resource:
kubectl patch spikeconfig my-config \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge
```

---

## Step 6 — Force a reconcile without changing spec

```bash
# Bumping an annotation changes resourceVersion, which fires a watch event.
kubectl annotate spikeconfig my-config \
  reconcile.spike.io/trigger="$(date +%s)" \
  --overwrite
```

Use this to kick a reconcile when you've fixed an external dependency and want the
controller to re-evaluate without waiting for the next scheduled requeue.

---

## Step 7 — Increase log verbosity temporarily

```bash
kubectl -n spike-system patch deploy spike-operator \
  -p '{"spec":{"template":{"spec":{"containers":[
    {"name":"manager","args":["--zap-log-level=debug"]}
  ]}}}}'

# Then tail and filter:
kubectl -n spike-system logs -f deploy/spike-operator \
  | grep -i "spikeconfig/my-config"
```

Debug level shows: reconcile start/end, cache hits, every status patch.

---

## Step 8 — Check if webhooks are blocking admission

```bash
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
# Check failurePolicy for each webhook — Fail means the operator pod must be healthy
```

If the webhook pod is down and `failurePolicy: Fail`, all creates/updates fail.
Emergency mitigation:

```bash
kubectl patch validatingwebhookconfiguration spike-validating-webhook \
  --type=json \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

Restore `failurePolicy: Fail` once the webhook pod is healthy.

---

## Step 9 — Detect goroutine leaks

```bash
# Requires: ctrl.Options{ PprofBindAddress: ":6060" } in your manager setup
kubectl -n spike-system port-forward deploy/spike-operator 6060:6060 &
curl -s 'localhost:6060/debug/pprof/goroutine?debug=2' | head -60
```

Look for large numbers of goroutines blocked on the same function. Common causes:

- A goroutine blocked on a channel read from a broken external client
- A goroutine waiting on a context that was never cancelled
- An `http.Client` with no timeout blocked on an unresponsive external service

---

## Step 10 — Cross-controller dependency triage

When multiple operators interact (A creates objects that B reconciles), a failure
in A silently blocks B's objects.

```bash
# Find all SpikeConfigs where the controller hasn't processed the latest spec
kubectl get spikeconfig -A -o json | \
  jq '.items[] | select(.metadata.generation != .status.observedGeneration) |
      {name: .metadata.name, ns: .metadata.namespace,
       gen: .metadata.generation, obs: .status.observedGeneration}'
```

Build a dashboard tracking `generation` vs `observedGeneration` across all your
CRD types. Objects drifting are your leading indicator that a controller is
falling behind or broken.

---

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Object stuck in `Pending` forever | Reconciler never runs: wrong predicate, or type not registered in `SetupWithManager` | Check metrics for zero reconcile count; verify `For()` / `Owns()` setup |
| Object stuck in `Terminating` | Finalizer present, operator down or cleanup erroring | Fix the operator or manually patch out the finalizer |
| Reconcile loop spinning (rapid re-reconciles) | Status update triggering watch event — missing `GenerationChangedPredicate` | Add `GenerationChangedPredicate` to `For()` |
| Status shows stale spec after `kubectl apply` | `observedGeneration` not set, or controller not reaching the status update | Set `sc.Status.ObservedGeneration = sc.Generation` before patching |
| CRD apply rejected after operator upgrade | New required field added without a schema default | Add `+kubebuilder:default=value` or make the field `+optional` |
| All creates/updates fail after webhook deployment | `failurePolicy: Fail` + webhook pod unavailable | Temporarily patch `failurePolicy` to `Ignore`; fix webhook pod |
| Controller reads stale data immediately after write | Informer cache lag | Work from the patched object; avoid re-`Get()` immediately after write |
| Operator DDoSing SPIRE/Vault on restart | Thundering herd — no concurrency limit or caching | Set `MaxConcurrentReconciles`, add request caching, add early-exit for no-op reconciles |
| Webhook rejecting updates for a specific user | RBAC on the webhook config, or `namespaceSelector` filtering the namespace | Check `webhookconfigurations` for `namespaceSelector` and `objectSelector` |
| `r.Status().Patch()` silently doing nothing | Forgot `WithStatusSubresource()` on the fake client (tests only) | Add `WithStatusSubresource(sc)` to `fake.NewClientBuilder()` |

---

## Quick reference: useful one-liners

```bash
# What version of the operator is running?
kubectl -n spike-system get deploy spike-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# How many objects is the operator managing?
kubectl get spikeconfig -A --no-headers | wc -l

# Show all objects NOT in Ready phase
kubectl get spikeconfig -A -o json | \
  jq '.items[] | select(.status.phase != "Ready") |
      {name: .metadata.name, ns: .metadata.namespace, phase: .status.phase}'

# Watch reconcile error rate in real time (requires watch + curl)
watch -n5 'curl -s localhost:8080/metrics | grep reconcile_total'

# Get last 50 lines of operator logs with timestamps
kubectl -n spike-system logs deploy/spike-operator \
  --tail=50 --timestamps=true

# Describe the leader lease
kubectl -n spike-system describe lease spike-operator-leader
```
