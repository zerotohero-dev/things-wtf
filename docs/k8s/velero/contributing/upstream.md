# Contributing Upstream

Velero is a CNCF graduated project with an active community. Contributing effectively requires understanding the governance structure and technical conventions.

## Governance

Velero uses a Maintainer + Approver model. The `MAINTAINERS.md` file in the repo lists current maintainers with their GitHub handles and affiliations.

**Maintainers** — can merge PRs, cut releases, set project direction.

**Approvers** — can approve PRs in their area of expertise. Becoming an approver requires sustained contributions + a nomination via the process in `GOVERNANCE.md`. A realistic timeline is 6–12 months of active contribution.

As of 2024-2025, major contributors include individuals from Broadcom/VMware, Red Hat, and independents. The project is genuinely vendor-neutral despite VMware's historical dominance in contribution volume.

## PR and issue conventions

- **File an issue before large PRs** — get buy-in on the design before implementing. Maintainers will often ask for a design doc for anything touching backup/restore logic or plugin interfaces.
- **Bug fixes**: reference the issue, include a test that reproduces the bug before the fix.
- **Features**: reference a `design/` document if significant.
- **DCO sign-off required**: `git commit --signoff` (the CLA bot checks for a `Signed-off-by` trailer).
- **Changelog fragment required**: every PR must include a file in `changelogs/unreleased/`.

```markdown
<!-- changelogs/unreleased/6789.md -->
## Changes

### Bug Fixes
* Fix nil pointer dereference in BackupItemAction when item has no labels (#6789, @yourhandle)

### Features
* Add support for custom BSL validation timeout (#6790, @yourhandle)
```

## High-value contribution areas (2024–2025)

### Kopia integration

The Restic→Kopia migration is complete but the integration still has rough edges: maintenance scheduling under concurrent uploads, repository locking behavior, large PVC performance. High-impact area with clear problems to solve.

**Starting point**: `pkg/uploader/kopia/` and `pkg/repository/` — look for open issues tagged `area/node-agent`.

### ItemSnapshotter v2 (alpha)

The new async snapshot plugin API (`design/item-snapshotter.md`) is still evolving. If you need custom snapshot semantics (e.g. vSphere FCD snapshot lifecycle control), this is the right extension point. Contributing spec clarity here influences the whole ecosystem.

**Starting point**: `pkg/plugin/velero/item_snapshotter.go` and related E2E tests.

### Multi-cluster BSL sync

Cross-cluster backup sync improvements. The `BackupSyncController` has known edge cases when BSLs are shared across clusters with different API versions or different Velero versions.

**Starting point**: `pkg/controller/backup_sync_controller.go`.

### Scale and performance

Clusters with 10k+ resources hit the API server hard during the backup list phase. Improvements to server-side filtering, chunked discovery, and concurrent list operations would benefit large enterprise deployments.

**Starting point**: `pkg/backup/item_collector.go` — the `getResources` function.

### E2E test coverage

The E2E suite is valuable but has gaps in CSI snapshot coverage and plugin system tests. New E2E tests get merged quickly.

**Starting point**: `pkg/test/e2e/` — look for `// TODO: add test for...` comments.

### Windows workload support

Windows node volume backup is incomplete. Low competition, high demand from enterprise users.

## Development workflow

```bash
# 1. Fork and clone
git clone https://github.com/YOUR_HANDLE/velero
cd velero
git remote add upstream https://github.com/vmware-tanzu/velero

# 2. Create a feature branch
git checkout -b fix/backup-nil-pointer-6789

# 3. Make changes, run tests
make test
make lint

# 4. Commit with sign-off
git commit --signoff -m "backup: fix nil pointer when item has no labels

Fixes #6789. The BackupItemAction executor was not checking for nil
labels map before ranging over it.

Signed-off-by: Volkan Özçelik <volkan@spiffe.io>"

# 5. Add changelog fragment
cat > changelogs/unreleased/6789.md << 'EOF'
## Changes
### Bug Fixes
* Fix nil pointer dereference in BackupItemAction when item has no labels (#6789, @volkanio)
EOF

# 6. Push and open PR
git push origin fix/backup-nil-pointer-6789
```

## What maintainers look for in PRs

- **Tests**: unit test for the change, E2E if it touches user-visible behavior
- **Changelog fragment**: required, CI will fail without it
- **Design doc** (for significant features): reference it in the PR description
- **Backward compatibility**: plugin interface changes must be carefully versioned
- **Documentation**: user-facing changes need a docs update in `site/docs/`

## Community channels

- **Slack**: `#velero` on [kubernetes.slack.com](https://kubernetes.slack.com)
- **Community meetings**: bi-weekly, schedule in `CONTRIBUTING.md`
- **GitHub Discussions**: for design proposals before opening an issue
- **Mailing list**: velero-users@googlegroups.com (low traffic)
