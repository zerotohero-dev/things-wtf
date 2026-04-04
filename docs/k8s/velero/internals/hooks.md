---
title: Hooks System
---

# Hooks System

Hooks are the mechanism for application-consistent backups. 

Understanding them is critical for anything stateful.

## Backup Hooks

Backup hooks run exec commands **in-pod** via the Kubernetes exec API. 

They are defined in the Backup spec or as pod annotations.

### Pre-Backup Hooks

Run before Velero snapshots the pod's volumes. 

Use to quiesce application state: flush dirty pages, lock tables, sync the 
filesystem. Hooks run concurrently for matched pods (*one goroutine per pod*).

### Post-Backup Hooks

Run after volume snapshot/data upload completes. 

Use to un-quiesce: unlock tables, resume writes. Velero guarantees the 
post hook runs even if the pre hook fails
(*unless `onError: Fail` aborted the backup entirely*).

### Spec-Level Hooks

```yaml
spec:
  hooks:
    resources:
    - name: mysql-hooks
      includedNamespaces: [production]
      labelSelector:
        matchLabels:
          app: mysql
      pre:
      - exec:
          container: mysql
          command:
            - /bin/bash
            - -c
            - "mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'FLUSH TABLES WITH READ LOCK;'"
          timeout: 30s
          onError: Fail    # Fail | Continue
      post:
      - exec:
          container: mysql
          command:
            - /bin/bash
            - -c
            - "mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'UNLOCK TABLES;'"
          timeout: 10s
          onError: Continue
```

### Annotation-Based Hooks (*preferred*)

```yaml
metadata:
  annotations:
    pre.hook.backup.velero.io/container: mysql
    pre.hook.backup.velero.io/command: >-
      ["/bin/bash", "-c",
       "mysql -uroot -p$PASS -e \"FLUSH TABLES WITH READ LOCK;\""]
    pre.hook.backup.velero.io/timeout: 30s
    pre.hook.backup.velero.io/on-error: Fail
    post.hook.backup.velero.io/container: mysql
    post.hook.backup.velero.io/command: >-
      ["/bin/bash", "-c",
       "mysql -uroot -p$PASS -e \"UNLOCK TABLES;\""]
    post.hook.backup.velero.io/on-error: Continue
```

!!! tip "Best Practice"
    Prefer annotation-based hooks. They keep backup semantics colocated with 
    the application manifest, survive cluster migrations, and don't require 
    modifying the central Backup spec for each new stateful app.

## Restore Hooks

Restore hooks are fundamentally different from backup hooks: 

They are implemented as **init containers injected into pod specs** before 
creation, not as exec commands into running pods.

### Init container injection

```yaml
spec:
  hooks:
    resources:
    - name: db-schema-migrate
      includedNamespaces: [production]
      labelSelector:
        matchLabels:
          app: myapp
      postHooks:
      - init:
          initContainers:
          - name: schema-migrate
            image: myapp:latest
            command: ["./migrate", "--up"]
            volumeMounts:
            - name: data
              mountPath: /data
          timeout: 5m
```

!!! example "Use Case: Zero-downtime schema migration"
    Restore init container hooks are powerful for zero-downtime schema 
    migrations on restore. 

    The app container doesn't start until the init container exits `0`, so you 
    can run database migrations before the app sees any traffic on the 
    restored cluster.

## Comparison

| Property            | Backup Pre/Post                    | Restore Init                                 |
|---------------------|------------------------------------|----------------------------------------------|
| Implementation      | `kubectl exec` into running pod    | Init container injected before pod create    |
| Pod must be running | Yes — skips if pod not `Running`   | No: pod doesn't exist yet                    |
| Timeout behavior    | Kills exec, applies onError policy | Kubernetes init container timeout semantics  |
| `onError: Fail`     | Backup fails (or partial)          | Restore of that pod fails                    |
| Multiple containers | Specify container name             | Multiple init containers in array            |
| Defined in          | Backup spec or pod annotations     | Restore spec only (no annotation equivalent) |

## Timeout Considerations

Backup hook timeouts default to `30s` if unspecified. 

For databases under write load, quiesce operations can take longer. Set 
explicit timeouts and monitor hook duration via Velero logs:

```bash
kubectl logs -n velero deployment/velero | grep "hook"
```

If a pre-backup hook times out and `onError: Fail`, the backup for that pod is 
marked as a warning/failure but the overall backup continues 
(*resulting in `PartiallyFailed`*).

## Next Up

[Plugin System](../extensions/plugins.md)