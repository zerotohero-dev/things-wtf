# Production Readiness Checklist

Work through this before shipping an operator to production. Each item represents a class of real production incidents.

---

## Reconcile Logic

- [x] **Reconcile is idempotent** — running N times produces the same result as once
- [x] **Handle `NotFound` at the top of reconcile** — object may be deleted mid-queue
- [x] **Always `DeepCopy` before mutating cache objects** — never mutate `r.Get()` results directly
- [x] **Return errors for transient failures** — let the work queue handle backoff
- [x] **Use `reconcile.TerminalError` for non-retryable conditions** — bad config, impossible constraints
- [x] **Multi-error collection** — attempt all sub-reconciliations even if one fails (`errors.Join`)
- [ ] **Avoid `Result{Requeue: true}`** — use `RequeueAfter` or rely on watch events
- [ ] **No spin-loops** — every error-return path has a sensible backoff story

## Status

- [x] **Use `r.Status().Update()`, not `r.Update()` for status changes**
- [x] **Set `status.observedGeneration = metadata.generation` in every status update**
- [x] **Use `metav1.Condition` for machine-readable conditions** — not custom boolean fields
- [x] **Status reflects observed reality**, not desired intent
- [ ] **Avoid infinite status-update loops** — use `GenerationChangedPredicate` on `For()`
- [ ] **Handle status update conflicts** — return error to requeue with fresh state

## Cache & Watches

- [x] **`GenerationChangedPredicate` on `For()` for spec-driven CRs** — filters status-only updates
- [x] **Field indexes registered before `mgr.Start()`**
- [x] **`MapFunc` does only cache lookups** — no API calls, no blocking operations
- [x] **Cache scoped to relevant namespaces or label selectors** in large clusters
- [ ] **Understand that `r.Get()` reads cache, not API server** — eventual consistency
- [ ] **`DeploymentStatusChangedPredicate` or equivalent on owned Deployments** — avoid metadata noise reconciles

## Ownership & Deletion

- [x] **`SetControllerReference` on all owned resources**
- [x] **All owned resources labeled with `app.kubernetes.io/managed-by`**
- [x] **Finalizers only for resources Kubernetes GC cannot clean up** (external DNS, cloud LBs)
- [x] **Finalizer cleanup resilient** — handles timeouts, partial failures, idempotent
- [ ] **Check `DeletionTimestamp.IsZero()` before adding finalizers**
- [ ] **No cross-namespace owner references**
- [ ] **Handle immutable field changes** (Deployment `spec.selector`) — detect and delete-recreate

## Operational

- [x] **Leader election enabled** with unique `LeaderElectionID`
- [x] **`LeaderElectionReleaseOnCancel: true`** — fast failover during rolling updates
- [x] **Liveness and readiness probes** on the operator Deployment
- [x] **`MaxConcurrentReconciles > 1`** if reconcile makes external calls or manages many objects
- [ ] **Rate limiter tuned** — default max of 1000s may be too aggressive for some use cases
- [ ] **RBAC follows least privilege** — audit generated ClusterRole, remove unused verbs
- [ ] **Events emitted** via `r.Recorder` for key state transitions (created, updated, errors)
- [ ] **Metrics exported** — monitor reconcile duration, error rate, queue depth

## Testing

- [x] **`envtest`-based integration tests** for happy path, update path, deletion
- [x] **Drift correction tested** — delete an owned resource, verify it's recreated
- [x] **Cascade delete tested** — delete CR, verify owned resources are gone
- [x] **Status conditions tested** — verify `Available` condition is set correctly
- [ ] **Finalizer cleanup path tested** — stub external dependency, verify cleanup + removal
- [ ] **Upgrade path tested** — apply old CRD version, upgrade operator, verify reconcile
- [ ] **Race detector clean** — `go test -race`
- [ ] **Load test** — create 100+ CRs, verify no reconcile storm or queue buildup

---

## Quick Debug Reference

```bash
# Watch controller logs in real time
kubectl logs -f -n webapp-operator-system \
  deploy/webapp-operator-controller-manager

# Check events for a specific WebApp
kubectl describe webapp my-app -n production

# Check all conditions on a WebApp
kubectl get webapp my-app -n production \
  -o jsonpath='{.status.conditions}' | jq

# Check observedGeneration vs generation
kubectl get webapp my-app -o jsonpath='{.metadata.generation} {.status.observedGeneration}'

# Check work queue metrics
kubectl port-forward -n webapp-operator-system svc/webapp-operator-metrics 8080
curl -s http://localhost:8080/metrics | grep -E 'workqueue|reconcile'

# Manually trigger reconcile by bumping an annotation
kubectl annotate webapp my-app reconcile/trigger=$(date +%s) --overwrite

# Check leader election lease
kubectl get lease webapp-operator.example.com -n webapp-operator-system
kubectl describe lease webapp-operator.example.com -n webapp-operator-system

# Force-remove a stuck finalizer (emergency only)
kubectl patch webapp my-app \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge

# See all resources managed by the operator
kubectl get all,ingresses \
  -l app.kubernetes.io/managed-by=webapp-operator \
  -A
```

---

## Common Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Object stuck in `Terminating` | Finalizer cleanup failing | Fix external dependency or force-remove finalizer |
| Reconcile storms (high CPU, many log lines) | Missing `GenerationChangedPredicate` or status-update loop | Add predicate, compare before status write |
| `status.observedGeneration` never advances | Wrong return path skipping status update | Ensure `updateStatus()` is always called |
| Deployment not updated after spec change | `CreateOrUpdate` mutate func not updating the right fields | Verify mutate func sets all fields you own |
| Cache returns stale data | Reading immediately after write (eventual consistency) | Don't re-read right after write; let next reconcile do it |
| Controller not triggering on ConfigMap change | Missing field index or wrong `MatchingFields` key | Register index, verify key name matches exactly |
| `cannot list resource` at startup | RBAC missing `list` verb | Add `list` to the marker, `make manifests`, reinstall |
| Operator crashes on leader failover | State held in memory, not in CR status | Move all operator state into CR `.status` |
| `conflict` errors on status update | Concurrent reconciles or external tooling writing status | Return error to requeue; or use `Status().Patch()` |
