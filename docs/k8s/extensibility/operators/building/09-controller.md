# 09 · Writing Your Controller

A complete, production-quality reconciler with all the important cases handled.
Read the comments — they explain every decision.

---

## Full reconciler

```go
package controller

import (
    "context"
    "fmt"
    "time"

    apierrors "k8s.io/apimachinery/pkg/api/errors"
    "k8s.io/apimachinery/pkg/api/meta"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/log"

    spikev1alpha1 "github.com/zerotohero-dev/spike-operator/api/v1alpha1"
)

// FinalizerName is the finalizer we add to control deletion cleanup.
// Convention: <controller-domain>/finalizer
const FinalizerName = "spike.io/finalizer"

// SpikeConfigReconciler holds dependencies your Reconcile function needs.
// The +rbac markers here are turned into RBAC YAML by controller-gen.
//
// +kubebuilder:rbac:groups=spike.io,resources=spikeconfigs,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=spike.io,resources=spikeconfigs/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=spike.io,resources=spikeconfigs/finalizers,verbs=update
// +kubebuilder:rbac:groups=core,resources=secrets,verbs=get;list;watch;create;update;patch;delete
type SpikeConfigReconciler struct {
    client.Client                  // embedded: gives you r.Get, r.List, r.Create, etc.
    Scheme *runtime.Scheme         // needed to set owner references
    // Add your own dependencies here and inject via cmd/main.go.
    // SPIREClient spire.WorkloadAPIClient
}

func (r *SpikeConfigReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // ── 1. Fetch the object ─────────────────────────────────────────────────
    var sc spikev1alpha1.SpikeConfig
    if err := r.Get(ctx, req.NamespacedName, &sc); err != nil {
        // IsNotFound = the object was deleted before we could process it.
        // This is normal. Return nil — no error, no requeue.
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // ── 2. Handle deletion ──────────────────────────────────────────────────
    // DeletionTimestamp is set by the API server when kubectl delete is called.
    // The object is NOT fully removed until all finalizers are removed.
    if !sc.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, &sc)
    }

    // ── 3. Ensure our finalizer is present ──────────────────────────────────
    if !controllerutil.ContainsFinalizer(&sc, FinalizerName) {
        controllerutil.AddFinalizer(&sc, FinalizerName)
        // This Update triggers a new watch event → another reconcile.
        // That's fine — next time we'll pass this block and do real work.
        if err := r.Update(ctx, &sc); err != nil {
            return ctrl.Result{}, fmt.Errorf("adding finalizer: %w", err)
        }
        return ctrl.Result{}, nil
    }

    // ── 4. Main reconciliation logic ────────────────────────────────────────
    return r.reconcileNormal(ctx, &sc)
}

func (r *SpikeConfigReconciler) reconcileNormal(
    ctx context.Context,
    sc *spikev1alpha1.SpikeConfig,
) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Create a patch baseline BEFORE making any changes.
    // MergeFrom captures current state so we compute a minimal diff.
    // Always deep-copy to avoid mutating the cache copy.
    patch := client.MergeFrom(sc.DeepCopy())

    expiry, err := r.ensureSVIDSecret(ctx, sc)
    if err != nil {
        log.Error(err, "failed to provision SVID secret")
        sc.Status.Phase = "Failed"
        meta.SetStatusCondition(&sc.Status.Conditions, metav1.Condition{
            Type:               "Ready",
            Status:             metav1.ConditionFalse,
            Reason:             "ProvisioningFailed",
            Message:            err.Error(),
            ObservedGeneration: sc.Generation,
        })
        // Best-effort status patch. Don't mask the original error.
        if patchErr := r.Status().Patch(ctx, sc, patch); patchErr != nil {
            log.Error(patchErr, "failed to patch status after error")
        }
        return ctrl.Result{}, err  // return original error for retry
    }

    // Happy path
    sc.Status.Phase = "Ready"
    sc.Status.ObservedGeneration = sc.Generation
    sc.Status.ExpiresAt = &metav1.Time{Time: expiry}
    meta.SetStatusCondition(&sc.Status.Conditions, metav1.Condition{
        Type:               "Ready",
        Status:             metav1.ConditionTrue,
        Reason:             "SVIDProvisioned",
        Message:            fmt.Sprintf("SVID issued, expires %s", expiry.Format(time.RFC3339)),
        ObservedGeneration: sc.Generation,
    })
    if err := r.Status().Patch(ctx, sc, patch); err != nil {
        return ctrl.Result{}, fmt.Errorf("patching status: %w", err)
    }

    // Requeue before expiry to rotate proactively
    rotateAt := time.Until(expiry) - 5*time.Minute
    if rotateAt < time.Minute {
        rotateAt = time.Minute
    }
    log.Info("SVID provisioned", "expiresAt", expiry, "requeueIn", rotateAt)
    return ctrl.Result{RequeueAfter: rotateAt}, nil
}

func (r *SpikeConfigReconciler) handleDeletion(
    ctx context.Context,
    sc *spikev1alpha1.SpikeConfig,
) (ctrl.Result, error) {
    if !controllerutil.ContainsFinalizer(sc, FinalizerName) {
        return ctrl.Result{}, nil  // Already cleaned up
    }

    // Do external cleanup here. Must be idempotent.
    if err := r.cleanupSPIFFEEntry(ctx, sc); err != nil {
        return ctrl.Result{}, fmt.Errorf("cleaning up SPIFFE entry: %w", err)
    }

    // Removal of the finalizer lets the API server delete the object.
    controllerutil.RemoveFinalizer(sc, FinalizerName)
    if err := r.Update(ctx, sc); err != nil {
        return ctrl.Result{}, fmt.Errorf("removing finalizer: %w", err)
    }
    return ctrl.Result{}, nil
}

func (r *SpikeConfigReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&spikev1alpha1.SpikeConfig{}).
        Owns(&corev1.Secret{}).
        Complete(r)
}
```

---

## Why we patch status even on failure

!!! info "Junior context — two separate concerns"

    Returning the error tells controller-runtime to retry. Patching the status
    tells humans and monitoring what's happening. Without the status patch, a user
    running `kubectl get spikeconfig my-config` would see no sign of failure —
    Phase would be blank. With it, they see `Phase: Failed` and a condition
    explaining why. Never leave the status silent on errors.

---

## The patch baseline pattern

```go
// Always take the baseline BEFORE modifying the struct.
patch := client.MergeFrom(sc.DeepCopy())

// Now mutate sc freely...
sc.Status.Phase = "Ready"
sc.Status.ObservedGeneration = sc.Generation

// Patch sends only the diff between the baseline and current state.
// This avoids accidental overwrites of fields other controllers own.
r.Status().Patch(ctx, sc, patch)
```

The `DeepCopy()` is critical. Without it, `patch` and `sc` point to the same
data, the diff is always empty, and nothing gets patched.

---

## Injecting dependencies via cmd/main.go

Your reconciler struct can hold any dependency:

```go
// In cmd/main.go, after building the manager:
if err := (&controller.SpikeConfigReconciler{
    Client:      mgr.GetClient(),
    Scheme:      mgr.GetScheme(),
    SPIREClient: spireClient,     // inject your external clients here
}).SetupWithManager(mgr); err != nil {
    setupLog.Error(err, "unable to create controller")
    os.Exit(1)
}
```
