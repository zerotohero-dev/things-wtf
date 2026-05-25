# 12 · Owner References

Owner references create a parent→child relationship. When the parent is deleted,
Kubernetes automatically garbage-collects all owned children — no finalizer
required on the child.

---

## Setting an owner reference

```go
secret := &corev1.Secret{
    ObjectMeta: metav1.ObjectMeta{
        Name:      sc.Name + "-svid",
        Namespace: sc.Namespace,
    },
    Data: map[string][]byte{
        "cert.pem": certPEM,
        "key.pem":  keyPEM,
    },
}

// SetControllerReference does three things:
// 1. Sets metadata.ownerReferences on the Secret pointing to SpikeConfig
// 2. Sets controller: true (marks this as the "controller" owner)
// 3. Sets blockOwnerDeletion: true (GC deletes Secret before SpikeConfig)
if err := ctrl.SetControllerReference(sc, secret, r.Scheme); err != nil {
    return time.Time{}, fmt.Errorf("setting owner reference: %w", err)
}
```

After this, when `SpikeConfig/my-config` is deleted, Kubernetes GC automatically
deletes `Secret/my-config-svid`. Zero cleanup code required.

---

## Drift repair via Owns()

The real power of owner references combined with `Owns()` in `SetupWithManager`
is **automatic drift repair**:

1. Someone manually deletes the Secret your operator created
2. The `Owns(&corev1.Secret{})` watch fires a reconcile for the parent `SpikeConfig`
3. Your `ensureSecret()` (which is idempotent) re-creates it

The cluster self-heals without any explicit drift-detection code.

---

## Owner references vs. finalizers

| | Owner references | Finalizers |
|---|---|---|
| **For** | Kubernetes objects you fully own | External state outside Kubernetes |
| **Examples** | Secrets, ConfigMaps, Deployments | Vault secrets, SPIFFE entries, AWS resources |
| **Cleanup** | Automatic (GC) | Manual (your cleanup function) |
| **Code required** | `SetControllerReference` only | `handleDeletion` + finalizer management |
| **Scope** | Same namespace only | Anything |

!!! warning "Cross-namespace owner references don't work"

    Owner references only work within the same namespace. A namespaced object cannot
    own a cluster-scoped object or an object in a different namespace. For
    cross-namespace or cluster-scoped cleanup, use a finalizer.
