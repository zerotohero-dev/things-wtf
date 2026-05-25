# Real Operator: WebApp — Full Implementation

Everything from the previous sections comes together here. This operator manages a `WebApp` CR that creates and maintains a `Deployment`, a `Service`, and optionally an `Ingress`. It handles status, finalizers, watches, predicates, and graceful updates.

---

## Controller Struct

```go title="internal/controller/webapp_controller.go"
package controller

import (
    "context"
    "fmt"

    appsv1    "k8s.io/api/apps/v1"
    corev1    "k8s.io/api/core/v1"
    netv1     "k8s.io/api/networking/v1"
    apierrors "k8s.io/apimachinery/pkg/api/errors"
    "k8s.io/apimachinery/pkg/api/meta"
    metav1    "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/types"
    "k8s.io/apimachinery/pkg/util/intstr"
    "k8s.io/client-go/tools/record"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/builder"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
    "sigs.k8s.io/controller-runtime/pkg/predicate"

    appsv1alpha1 "github.com/yourorg/webapp-operator/api/v1alpha1"
)

// +kubebuilder:rbac:groups=apps.example.com,resources=webapps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps.example.com,resources=webapps/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps.example.com,resources=webapps/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=events,verbs=create;patch

type WebAppReconciler struct {
    client.Client
    Scheme   *runtime.Scheme
    Recorder record.EventRecorder
}

const (
    finalizerName        = "apps.example.com/webapp-finalizer"
    fieldManagerName     = "webapp-operator"
    conditionAvailable   = "Available"
    conditionProgressing = "Progressing"
)
```

---

## The Main Reconcile Function

```go title="internal/controller/webapp_controller.go — Reconcile"
func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    webapp := &appsv1alpha1.WebApp{}
    if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // ── Finalizer registration ────────────────────────────────────────────
    if webapp.DeletionTimestamp.IsZero() {
        if !controllerutil.ContainsFinalizer(webapp, finalizerName) {
            controllerutil.AddFinalizer(webapp, finalizerName)
            if err := r.Update(ctx, webapp); err != nil {
                return ctrl.Result{}, fmt.Errorf("adding finalizer: %w", err)
            }
            return ctrl.Result{}, nil
        }
    } else {
        // ── Deletion handling ─────────────────────────────────────────────
        if controllerutil.ContainsFinalizer(webapp, finalizerName) {
            if err := r.cleanupExternalResources(ctx, webapp); err != nil {
                return ctrl.Result{}, fmt.Errorf("cleanup: %w", err)
            }
            controllerutil.RemoveFinalizer(webapp, finalizerName)
            if err := r.Update(ctx, webapp); err != nil {
                return ctrl.Result{}, fmt.Errorf("removing finalizer: %w", err)
            }
        }
        return ctrl.Result{}, nil
    }

    // ── Reconcile sub-resources ───────────────────────────────────────────
    var errs []error

    if err := r.reconcileDeployment(ctx, webapp); err != nil {
        errs = append(errs, fmt.Errorf("deployment: %w", err))
    }
    if err := r.reconcileService(ctx, webapp); err != nil {
        errs = append(errs, fmt.Errorf("service: %w", err))
    }
    if webapp.Spec.Ingress != nil {
        if err := r.reconcileIngress(ctx, webapp); err != nil {
            errs = append(errs, fmt.Errorf("ingress: %w", err))
        }
    }

    // ── Status update — always attempt, even on partial failure ──────────
    if statusErr := r.updateStatus(ctx, webapp); statusErr != nil {
        errs = append(errs, fmt.Errorf("status: %w", statusErr))
    }

    return ctrl.Result{}, errors.Join(errs...)
}
```

---

## Deployment Reconciliation

```go title="internal/controller — reconcileDeployment"
func (r *WebAppReconciler) reconcileDeployment(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    log := log.FromContext(ctx)
    desired := r.buildDeployment(webapp)

    if err := controllerutil.SetControllerReference(webapp, desired, r.Scheme); err != nil {
        return err
    }

    existing := &appsv1.Deployment{}
    err := r.Get(ctx, types.NamespacedName{Namespace: webapp.Namespace, Name: webapp.Name}, existing)

    switch {
    case apierrors.IsNotFound(err):
        log.Info("Creating Deployment")
        if err := r.Create(ctx, desired); err != nil {
            r.Recorder.Event(webapp, corev1.EventTypeWarning, "CreateFailed",
                fmt.Sprintf("Failed to create Deployment: %v", err))
            return fmt.Errorf("creating Deployment: %w", err)
        }
        r.Recorder.Event(webapp, corev1.EventTypeNormal, "Created", "Deployment created successfully")
        return nil

    case err != nil:
        return fmt.Errorf("fetching Deployment: %w", err)

    default:
        // Deployment exists — patch only what we own.
        // Copy desired fields onto existing to avoid overwriting
        // fields managed by other controllers (e.g., HPA sets replica count).
        patch := client.MergeFrom(existing.DeepCopy())

        // Only set replicas if HPA is NOT managing this deployment
        // (In a real operator, check for HPA existence first)
        existing.Spec.Replicas = &webapp.Spec.Replicas

        // Update only our container — don't touch sidecars injected by webhooks
        for i, c := range existing.Spec.Template.Spec.Containers {
            if c.Name == "webapp" {
                existing.Spec.Template.Spec.Containers[i].Image     = webapp.Spec.Image
                existing.Spec.Template.Spec.Containers[i].Env       = webapp.Spec.Env
                existing.Spec.Template.Spec.Containers[i].Resources = webapp.Spec.Resources
                existing.Spec.Template.Spec.Containers[i].Ports     = []corev1.ContainerPort{
                    {ContainerPort: webapp.Spec.Port},
                }
                break
            }
        }

        // Compute patch data — skip if nothing changed
        patchData, _ := patch.Data(existing)
        if string(patchData) == "{}" {
            return nil // no-op
        }

        if err := r.Patch(ctx, existing, patch); err != nil {
            if apierrors.IsInvalid(err) {
                // Immutable field changed (e.g., selector) — must delete and recreate
                log.Info("Deployment has immutable field change, deleting for recreation")
                if delErr := r.Delete(ctx, existing); delErr != nil {
                    return fmt.Errorf("deleting stale deployment: %w", delErr)
                }
                return fmt.Errorf("deployment deleted, will recreate on next reconcile")
            }
            return fmt.Errorf("patching Deployment: %w", err)
        }
        log.Info("Deployment patched")
    }
    return nil
}

func (r *WebAppReconciler) buildDeployment(webapp *appsv1alpha1.WebApp) *appsv1.Deployment {
    ls := map[string]string{
        "app.kubernetes.io/name":       webapp.Name,
        "app.kubernetes.io/managed-by": "webapp-operator",
    }
    replicas := webapp.Spec.Replicas

    return &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            Labels:    ls,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &replicas,
            Selector: &metav1.LabelSelector{MatchLabels: ls},
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{Labels: ls},
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{{
                        Name:      "webapp",
                        Image:     webapp.Spec.Image,
                        Ports:     []corev1.ContainerPort{{ContainerPort: webapp.Spec.Port}},
                        Env:       webapp.Spec.Env,
                        Resources: webapp.Spec.Resources,
                        ReadinessProbe: &corev1.Probe{
                            ProbeHandler: corev1.ProbeHandler{
                                HTTPGet: &corev1.HTTPGetAction{
                                    Path: "/",
                                    Port: intstr.FromInt32(webapp.Spec.Port),
                                },
                            },
                            InitialDelaySeconds: 5,
                            PeriodSeconds:       10,
                        },
                    }},
                },
            },
        },
    }
}
```

---

## Service Reconciliation

```go title="internal/controller — reconcileService"
func (r *WebAppReconciler) reconcileService(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    desired := &corev1.Service{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            Labels: map[string]string{
                "app.kubernetes.io/name":       webapp.Name,
                "app.kubernetes.io/managed-by": "webapp-operator",
            },
        },
        Spec: corev1.ServiceSpec{
            Selector: map[string]string{
                "app.kubernetes.io/name": webapp.Name,
            },
            Ports: []corev1.ServicePort{{
                Port:       80,
                TargetPort: intstr.FromInt32(webapp.Spec.Port),
                Protocol:   corev1.ProtocolTCP,
            }},
            Type: corev1.ServiceTypeClusterIP,
        },
    }

    if err := controllerutil.SetControllerReference(webapp, desired, r.Scheme); err != nil {
        return err
    }

    _, err := controllerutil.CreateOrUpdate(ctx, r.Client, desired, func() error {
        // Update only the port mapping — ClusterIP is assigned by API server and must not be changed
        desired.Spec.Ports = []corev1.ServicePort{{
            Port:       80,
            TargetPort: intstr.FromInt32(webapp.Spec.Port),
            Protocol:   corev1.ProtocolTCP,
        }}
        return nil
    })
    return err
}
```

---

## Ingress Reconciliation

```go title="internal/controller — reconcileIngress"
func (r *WebAppReconciler) reconcileIngress(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    if webapp.Spec.Ingress == nil {
        // Spec no longer wants an Ingress — delete if it exists
        existing := &netv1.Ingress{}
        err := r.Get(ctx, types.NamespacedName{Namespace: webapp.Namespace, Name: webapp.Name}, existing)
        if err == nil {
            return r.Delete(ctx, existing)
        }
        return client.IgnoreNotFound(err)
    }

    pathType := netv1.PathTypePrefix
    desired := &netv1.Ingress{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            Labels: map[string]string{
                "app.kubernetes.io/name":       webapp.Name,
                "app.kubernetes.io/managed-by": "webapp-operator",
            },
            Annotations: r.ingressAnnotations(webapp),
        },
        Spec: netv1.IngressSpec{
            IngressClassName: webapp.Spec.Ingress.IngressClassName,
            Rules: []netv1.IngressRule{{
                Host: webapp.Spec.Ingress.Host,
                IngressRuleValue: netv1.IngressRuleValue{
                    HTTP: &netv1.HTTPIngressRuleValue{
                        Paths: []netv1.HTTPIngressPath{{
                            Path:     "/",
                            PathType: &pathType,
                            Backend: netv1.IngressBackend{
                                Service: &netv1.IngressServiceBackend{
                                    Name: webapp.Name,
                                    Port: netv1.ServiceBackendPort{Number: 80},
                                },
                            },
                        }},
                    },
                },
            }},
        },
    }

    if webapp.Spec.Ingress.TLS {
        desired.Spec.TLS = []netv1.IngressTLS{{
            Hosts:      []string{webapp.Spec.Ingress.Host},
            SecretName: webapp.Name + "-tls",
        }}
    }

    if err := controllerutil.SetControllerReference(webapp, desired, r.Scheme); err != nil {
        return err
    }

    _, err := controllerutil.CreateOrUpdate(ctx, r.Client, desired, func() error {
        desired.Spec.Rules = desired.Spec.Rules
        desired.Spec.TLS = desired.Spec.TLS
        desired.Annotations = r.ingressAnnotations(webapp)
        return nil
    })
    return err
}

func (r *WebAppReconciler) ingressAnnotations(webapp *appsv1alpha1.WebApp) map[string]string {
    ann := map[string]string{}
    if webapp.Spec.Ingress.TLS {
        ann["cert-manager.io/cluster-issuer"] = "letsencrypt-prod"
    }
    return ann
}
```

---

## SetupWithManager — Full Configuration

```go title="internal/controller — SetupWithManager"
func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    // Register field index before building the controller
    if err := mgr.GetFieldIndexer().IndexField(
        context.Background(), &appsv1alpha1.WebApp{}, ".spec.configMapRef",
        func(o client.Object) []string {
            wa := o.(*appsv1alpha1.WebApp)
            if wa.Spec.ConfigMapRef == "" { return nil }
            return []string{wa.Spec.ConfigMapRef}
        },
    ); err != nil {
        return fmt.Errorf("field indexer: %w", err)
    }

    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.WebApp{},
            // Reconcile on spec changes or annotation changes.
            // Status updates filtered out — avoids reconcile storm.
            builder.WithPredicates(predicate.Or(
                predicate.GenerationChangedPredicate{},
                predicate.AnnotationChangedPredicate{},
            )),
        ).
        Owns(&appsv1.Deployment{},
            builder.WithPredicates(DeploymentStatusChangedPredicate{}),
        ).
        Owns(&corev1.Service{},
            builder.WithPredicates(predicate.ResourceVersionChangedPredicate{}),
        ).
        Owns(&netv1.Ingress{}).
        Watches(&corev1.ConfigMap{},
            handler.EnqueueRequestsFromMapFunc(r.findWebAppsForConfigMap),
            builder.WithPredicates(predicate.ResourceVersionChangedPredicate{}),
        ).
        WithOptions(controller.Options{
            MaxConcurrentReconciles: 3,
        }).
        Complete(r)
}

func (r *WebAppReconciler) findWebAppsForConfigMap(
    ctx context.Context, obj client.Object,
) []reconcile.Request {
    list := &appsv1alpha1.WebAppList{}
    if err := r.List(ctx, list,
        client.InNamespace(obj.GetNamespace()),
        client.MatchingFields{".spec.configMapRef": obj.GetName()},
    ); err != nil {
        return nil
    }
    reqs := make([]reconcile.Request, len(list.Items))
    for i, wa := range list.Items {
        reqs[i] = reconcile.Request{NamespacedName: types.NamespacedName{
            Namespace: wa.Namespace, Name: wa.Name,
        }}
    }
    return reqs
}
```

---

## Registering the Controller in main.go

```go title="cmd/main.go"
if err = (&controller.WebAppReconciler{
    Client:   mgr.GetClient(),
    Scheme:   mgr.GetScheme(),
    Recorder: mgr.GetEventRecorderFor("webapp-controller"),
}).SetupWithManager(mgr); err != nil {
    setupLog.Error(err, "unable to create controller", "controller", "WebApp")
    os.Exit(1)
}
```

---

## Quick Smoke Test

```bash
# Install CRDs
make install

# Run controller locally
make run &

# Create a WebApp
cat <<EOF | kubectl apply -f -
apiVersion: apps.example.com/v1alpha1
kind: WebApp
metadata:
  name: my-app
  namespace: default
spec:
  image: nginx:1.25
  replicas: 2
  port: 80
  ingress:
    host: my-app.example.com
    tls: false
EOF

# Watch reconcile progress
kubectl get webapp my-app -w

# Verify owned resources were created
kubectl get deployment,service,ingress -l app.kubernetes.io/name=my-app

# Test drift correction — delete the deployment manually
kubectl delete deployment my-app
kubectl get deployment my-app  # Should reappear within seconds

# Test deletion cascade
kubectl delete webapp my-app
kubectl get deployment,service,ingress -l app.kubernetes.io/name=my-app  # All gone
```
