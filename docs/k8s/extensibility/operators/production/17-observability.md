# 17 · Observability

Observability for operators has three pillars: metrics (what is happening),
logs (what happened), and traces (why it's slow). controller-runtime provides
substantial built-in support for the first two; tracing requires a small amount
of wiring.

---

## Built-in Prometheus metrics

controller-runtime exposes metrics at `:8080/metrics` with zero extra code.

```bash
kubectl -n spike-system port-forward deploy/spike-operator 8080:8080 &
curl -s localhost:8080/metrics | grep controller_runtime
```

### Key metrics to alert on

| Metric | Alert condition | What it means |
|---|---|---|
| `controller_runtime_reconcile_total{result="error"}` | Increasing rate | Something is broken in Reconcile() |
| `controller_runtime_active_workers` | Pinned at max | Goroutine leak or blocking reconcile |
| `controller_runtime_reconcile_time_seconds` | p99 > threshold | Slow external calls (SPIRE, Vault) |
| `controller_runtime_reconcile_total{result="requeue"}` | Very high rate | Tight requeue loop — check predicates |
| `rest_client_requests_total{code="429"}` | Any | API server rate-limiting your operator |

---

## Custom domain metrics

```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

// Declare at package level — promauto registers with the default registry.
var (
    svidsProvisioned = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "spike_svids_provisioned_total",
        Help: "Total SVIDs provisioned, partitioned by type.",
    }, []string{"type"})

    svidsExpired = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "spike_svids_expired_total",
        Help: "SVIDs that expired before rotation (indicates missed requeue).",
    }, []string{"type"})

    svidProvisionDuration = promauto.NewHistogram(prometheus.HistogramOpts{
        Name:    "spike_svid_provision_duration_seconds",
        Help:    "Time to provision an SVID from SPIRE.",
        Buckets: []float64{.005, .01, .05, .1, .5, 1, 5, 10},
    })

    // A Gauge for the number of managed objects, useful for capacity planning
    managedSpikeConfigs = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "spike_managed_configs_total",
        Help: "Number of SpikeConfig objects currently managed.",
    })
)

// In Reconcile():
timer := prometheus.NewTimer(svidProvisionDuration)
defer timer.ObserveDuration()

svidsProvisioned.WithLabelValues(sc.Spec.SVIDType).Inc()
```

---

## Structured logging

controller-runtime uses `logr` backed by `zap`. Use the context-bound logger to
get automatic namespace/name fields injected:

```go
func (r *R) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // Already has: controller=spikeconfig, name=..., namespace=...
    log := log.FromContext(ctx)

    // Add more fields relevant to this reconcile pass
    log = log.WithValues(
        "workloadId", sc.Spec.WorkloadId,
        "generation", sc.Generation,
    )

    log.Info("reconciling")
    log.V(1).Info("debug detail", "ttl", sc.Spec.TTL)  // V(1) = debug level
    log.Error(err, "failed to provision", "cause", err.Error())
}
```

### Increase verbosity at runtime (no restart needed)

```bash
kubectl -n spike-system patch deploy spike-operator \
  -p '{"spec":{"template":{"spec":{"containers":[
    {"name":"manager","args":["--zap-log-level=debug"]}
  ]}}}}'
```

Log levels:

| Flag | What you see |
|---|---|
| `--zap-log-level=info` | Default. Info, warning, error. |
| `--zap-log-level=debug` | Above + V(1) debug lines |
| `--zap-log-level=5` | Above + informer cache hits and reconcile scheduling |

---

## OpenTelemetry tracing

??? example "Deep dive: wiring up distributed tracing"

    For operators making multiple external calls per reconcile, tracing helps you
    identify which call is slow. The context flows naturally through controller-runtime:

    ```go
    import (
        "go.opentelemetry.io/otel"
        "go.opentelemetry.io/otel/attribute"
        "go.opentelemetry.io/otel/trace"
    )

    func (r *R) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
        ctx, span := otel.Tracer("spike-operator").Start(ctx, "Reconcile",
            trace.WithAttributes(
                attribute.String("name", req.Name),
                attribute.String("namespace", req.Namespace),
            ),
        )
        defer span.End()

        // All downstream calls inherit the span via ctx:
        ctx, cspan := otel.Tracer("spike-operator").Start(ctx, "provisionSVID")
        expiry, err := r.spireClient.ProvisionSVID(ctx, sc.Spec.WorkloadId)
        cspan.End()

        if err != nil {
            span.RecordError(err)
            return ctrl.Result{}, err
        }

        return ctrl.Result{RequeueAfter: time.Until(expiry) - 5*time.Minute}, nil
    }
    ```

    Configure an OTLP exporter in `cmd/main.go` and point it at your Jaeger or
    Tempo instance. Every reconcile becomes a traceable span with child spans for
    external calls, so you can see exactly where time is spent.

---

## Health endpoints

controller-runtime registers `/healthz` and `/readyz` automatically. Add your
own checks when readiness depends on external state:

```go
mgr, err := ctrl.NewManager(cfg, ctrl.Options{
    HealthProbeBindAddress: ":8081",
})

// Add a custom readiness check — useful to block traffic until the cache syncs
mgr.AddReadyzCheck("cache-sync", func(req *http.Request) error {
    if !mgr.GetCache().WaitForCacheSync(req.Context()) {
        return fmt.Errorf("cache not synced")
    }
    return nil
})

// Add a custom liveness check — useful to detect a stuck reconcile
mgr.AddHealthzCheck("heartbeat", healthz.Ping)
```
