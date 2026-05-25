# 14 · Server-Side Apply

**Server-Side Apply (SSA)** is a newer, more correct way to apply changes to
Kubernetes objects. Instead of the client computing a diff and sending a full
update, the client sends only the fields it *owns*, and the API server merges them
server-side, tracking field ownership per manager.

---

## Client-side vs. server-side apply

| | Client-Side Apply (old) | Server-Side Apply (new) |
|---|---|---|
| Who computes the diff | Client | API server |
| What is sent | Full object body | Only owned fields |
| Field ownership tracking | None | Per-field, per-manager |
| Concurrent manager safety | Race-prone | Conflicts surfaced explicitly |
| Idempotency | Fragile | Strong |

!!! info "Junior context"

    The old pattern (`r.Create` / `r.Update`) requires the client to first fetch the
    object, compute a diff, and decide what to do. This is error-prone when two
    controllers both touch the same object — one can silently clobber the other's
    fields. SSA solves this: the API server knows exactly which manager owns which
    fields and rejects conflicts rather than silently losing data.

---

## SSA in practice

```go
// Build the object with only the fields you own.
// TypeMeta is required for SSA — it tells the API server what you're managing.
desired := &corev1.ConfigMap{
    TypeMeta: metav1.TypeMeta{
        APIVersion: "v1",
        Kind:       "ConfigMap",
    },
    ObjectMeta: metav1.ObjectMeta{
        Name:      "spike-config",
        Namespace: sc.Namespace,
    },
    Data: map[string]string{
        "ttl": strconv.FormatInt(sc.Spec.TTL, 10),
    },
}

// Apply: idempotent, ownership-tracking, no conflict on fields you don't own.
// FieldOwner identifies your controller as the manager of these fields.
err := r.Patch(
    ctx,
    desired,
    client.Apply,
    client.FieldOwner("spike-operator"),
    client.ForceOwnership,  // take ownership if another manager claims a field you set
)
if err != nil {
    return ctrl.Result{}, fmt.Errorf("SSA patch: %w", err)
}
```

The call is **always safe to repeat** — if the object doesn't exist, SSA creates
it; if it exists and the fields match, it's a no-op; if fields differ, only the
changed fields are updated.

---

## When to prefer SSA

Use SSA for:

- Creating and managing Kubernetes objects within your reconciler
- Any object where multiple controllers might touch different fields
- Situations where you want the API server to enforce field ownership

Continue using `r.Status().Patch(ctx, sc, client.MergeFrom(baseline))` for
status updates — status is a subresource with its own endpoint and SSA is not
needed there.

!!! tip "Flux uses SSA exclusively"

    Flux's kustomize-controller applies every resource via SSA. This is why Flux
    can safely co-exist with other tools that also manage resources: field ownership
    is tracked, so each manager only touches what it declared.

---

## ForceOwnership vs. conflict errors

Without `client.ForceOwnership`, if another manager owns a field you're trying
to set, the API server returns a conflict error. You then have two choices:

1. Resolve the conflict by removing the field from your apply (let the other manager own it)
2. Use `ForceOwnership` to take over the field

Use `ForceOwnership` when you know your controller is the authoritative source for
that field. Use conflict errors (without force) when you want to be notified if
something else is managing a field you expected to own.
