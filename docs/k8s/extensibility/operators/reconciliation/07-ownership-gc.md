# Ownership & Garbage Collection

When you create a resource (Deployment, Service, etc.) on behalf of your CR, set an **owner reference** pointing to the CR. When the CR is deleted, Kubernetes GC will automatically cascade-delete all owned resources. This eliminates the need for finalizers for Kubernetes-native resources.

---

## SetControllerReference

```go title="internal/controller — setting owner references"
import "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

func (r *WebAppReconciler) reconcileDeployment(ctx context.Context, webapp *appsv1alpha1.WebApp) error {
    desired := r.buildDeployment(webapp)

    // Set the WebApp as the owner. When WebApp is deleted, this Deployment
    // will be garbage-collected automatically.
    if err := controllerutil.SetControllerReference(webapp, desired, r.Scheme); err != nil {
        return fmt.Errorf("setting owner reference: %w", err)
    }

    // CreateOrUpdate: fetches existing, calls your mutate fn, creates or patches
    result, err := controllerutil.CreateOrUpdate(ctx, r.Client, desired, func() error {
        // This function is called with `desired` pre-populated with the server's
        // current version (if the object exists). Mutate only the fields you own.
        desired.Spec.Replicas = &webapp.Spec.Replicas
        desired.Spec.Template.Spec.Containers[0].Image = webapp.Spec.Image
        desired.Spec.Template.Spec.Containers[0].Resources = webapp.Spec.Resources
        return nil
    })
    if err != nil {
        return fmt.Errorf("create/update deployment: %w", err)
    }

    log.FromContext(ctx).Info("Deployment reconciled", "result", result)
    return nil
}
```

---

## SetControllerReference vs SetOwnerReference

| Function | Controller flag | blockOwnerDeletion | Use case |
|----------|----------------|-------------------|---------|
| `SetControllerReference` | `true` | `true` | You are the sole controller of this resource. Only one controller reference per object is allowed. |
| `SetOwnerReference` | `false` | configurable | You want GC cascade but aren't the controller. Multiple owners allowed. |

Use `SetControllerReference` for all resources you create and fully manage.

---

## The CreateOrUpdate Pattern in Detail

`controllerutil.CreateOrUpdate` is a convenience wrapper that:

1. Tries `r.Get()` for the object
2. If not found → calls your mutate func → calls `r.Create()`
3. If found → calls your mutate func with current state pre-populated → calls `r.Update()` if changed

```go
result, err := controllerutil.CreateOrUpdate(ctx, r.Client, obj, func() error {
    // This mutate func MUST be idempotent.
    // It's called both on create AND on update.
    // On update, obj already contains the server's current state.
    // Only set the fields you own.
    obj.Spec.Replicas = &desired
    return nil
})

switch result {
case controllerutil.OperationResultCreated:
    r.Recorder.Event(webapp, corev1.EventTypeNormal, "Created", "Deployment created")
case controllerutil.OperationResultUpdated:
    r.Recorder.Event(webapp, corev1.EventTypeNormal, "Updated", "Deployment updated")
case controllerutil.OperationResultNone:
    // no-op, nothing changed
}
```

---

## The Immutable Label Selector Gotcha

!!! danger "Deployment spec.selector is immutable after creation"
    `spec.selector` in a Deployment cannot be changed after creation. If you try to `CreateOrUpdate` a Deployment and change its label selector (say you changed how pods are labeled), the update will fail with a validation error.

    Your reconciler must detect this and **delete-then-recreate** the Deployment:

    ```go
    result, err := controllerutil.CreateOrUpdate(ctx, r.Client, desired, mutateFn)
    if err != nil {
        if apierrors.IsInvalid(err) && strings.Contains(err.Error(), "selector") {
            // Selector changed — must delete and recreate
            log.Info("Deployment selector changed, recreating")
            if delErr := r.Delete(ctx, existing); delErr != nil {
                return fmt.Errorf("deleting stale deployment: %w", delErr)
            }
            // Return error to requeue — next reconcile will Create fresh
            return fmt.Errorf("deployment deleted for recreation: will reconcile")
        }
        return err
    }
    ```

    **Prevention is better:** use a `+kubebuilder:validation:XValidation` CEL rule to prevent label-selector-affecting spec changes after creation.

---

## Cross-Namespace Owner References Are Forbidden

!!! danger "Cross-namespace ownership does not work"
    Kubernetes does not allow owner references to cross namespaces:

    - If your CR is in namespace `foo`, you **cannot** own a resource in namespace `bar`
    - **Cluster-scoped resources** (ClusterRole, ClusterRoleBinding, etc.) **cannot** be owned by namespace-scoped resources

    For cross-namespace or cluster-scoped cleanup, you need [finalizers](./06-finalizers.md).

---

## Verifying Ownership

```bash
# See owner references on a resource
kubectl get deployment my-app -o jsonpath='{.metadata.ownerReferences}'

# See all resources owned by a WebApp (via label selector if you label owned resources)
kubectl get all -l app.kubernetes.io/name=my-webapp -n production

# Watch GC cascade: delete the WebApp and see owned resources disappear
kubectl delete webapp my-app
kubectl get deployment my-app  # Should 404 shortly after
```

---

## Protecting Owned Resources from External Deletion

Owner references cause cascade GC on CR deletion. But what about someone manually deleting the Deployment? Because you use `Owns(&appsv1.Deployment{})` in `SetupWithManager`, the controller watches all owned Deployments. A manual delete fires a watch event → reconcile runs → Deployment is re-created.

This is the operator's **drift correction** — one of the key values over Helm.

```bash
# Try to break it
kubectl delete deployment my-webapp -n production

# Watch the operator restore it (should take <1 second)
kubectl get deployment my-webapp -n production -w
```
