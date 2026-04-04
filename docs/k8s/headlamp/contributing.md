# Contributor Workflow

Headlamp follows a standard GitHub fork/PR workflow with a few project-specific conventions.

## Before you write code

For **non-trivial changes** — new features, architectural changes, new APIs — open a GitHub issue first. Maintainers will give direction before you spend time writing code.

Small bug fixes and documentation improvements can go straight to a PR.

## Setup

```bash
# fork on GitHub, then:
git clone https://github.com/YOUR_USERNAME/headlamp
cd headlamp
git remote add upstream https://github.com/kubernetes-sigs/headlamp
git checkout -b feat/my-feature
```

Keep your branch rebased on `upstream/main`:

```bash
git fetch upstream
git rebase upstream/main
```

## Development cycle

```bash
# 1. Build and run
npm run backend:build
npm run backend:start     # terminal 1
npm run frontend:start    # terminal 2

# 2. Make your changes

# 3. Test
npm run backend:test
npm run frontend:test

# 4. Lint and format
npm run backend:lint
npm run backend:format
npm run frontend:lint

# 5. Commit with DCO sign-off (required)
git commit -s -m "feat(helm): add service proxy timeout config"
```

## DCO (Developer Certificate of Origin)

Every commit must be signed off with `-s`:

```bash
git commit -s -m "your message"
# adds: Signed-off-by: Your Name <your@email.com>
```

To configure git to always add sign-off:

```bash
# add to ~/.gitconfig
[alias]
    ci = commit -s
```

## Commit message format

```
type(scope): short description

Longer explanation if needed.

Fixes #123
```

| Type | When |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that isn't a feature or fix |
| `test` | Adding or fixing tests |
| `chore` | Build, CI, dependency changes |

Scopes: `helm`, `plugins`, `frontend`, `backend`, `chart`, `auth`, `oidc`, etc.

## Writing tests

Go packages have `*_test.go` files alongside each `*.go` file. Use table-driven tests:

```go
func TestServiceProxyURL(t *testing.T) {
    tests := []struct {
        name      string
        namespace string
        service   string
        path      string
        want      string
    }{
        {"basic", "default", "my-svc", "api/charts", "/serviceproxy/default/my-svc/api/charts"},
        // ...
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := buildProxyURL(tt.namespace, tt.service, tt.path)
            if got != tt.want {
                t.Errorf("got %q, want %q", got, tt.want)
            }
        })
    }
}
```

Frontend components require both a Jest test and a Storybook story:

```
Button.tsx
Button.test.tsx      # Jest / React Testing Library
Button.stories.tsx   # Storybook story
```

## Opening the PR

1. Push your branch: `git push origin feat/my-feature`
2. Open a PR against `kubernetes-sigs/headlamp:main`
3. Fill out the PR template — include: what changed, why, how to test
4. Link the related issue: `Fixes #123`
5. CI runs lint, tests, and build checks automatically

## Contribution ideas (SPIFFE/Kubernetes focus)

These are high-value gaps that map well to platform engineering experience:

| Idea | What it involves |
|---|---|
| **SPIRE visualization plugin** | List `SpiffeEntry` CRDs, graph SVID expirations, show attestation status per pod. Pure plugin work — no backend changes needed |
| **ESO topology plugin** | Visualize `SecretStore` → `ExternalSecret` dependency graphs; show sync status and error messages |
| **Velero plugin** | Backup/restore workflow UI, backup location status, SVID-based BSL authentication display |
| **App Catalog non-OIDC fix** | Fix issue [#4788](https://github.com/kubernetes-sigs/headlamp/issues/4788) — the service proxy Authorization header forwarding bug with token auth |
| **Flux plugin improvements** | HelmRelease visualization, reconciliation status, source graph — the existing plugin has room to grow |
| **FIPS-compliant image** | Build Headlamp with `GOFIPS140` mode and publish a FIPS-tagged image variant |
| **Multi-cluster SVID comparison** | Cross-cluster view showing SVID TTLs and trust domains across all managed clusters |

## Code conventions

### Go

- Packages go in `backend/pkg/`. The `cmd/` directory is for wiring only.
- Each package ships a `*_test.go` file — no test files in `cmd/`.
- Run `npm run backend:format` before committing. The CI uses `gofmt -s` and `goimports`.
- Use the project's error wrapping conventions: `fmt.Errorf("context: %w", err)`.

### TypeScript / React

- Components in `frontend/src/components/`. Keep each component in its own directory with `index.tsx`, `*.test.tsx`, and `*.stories.tsx`.
- Import from `@kinvolk/headlamp-plugin/lib` in plugin code — do not import from `frontend/src/` directly.
- Prefer functional components and hooks over class components.
- MUI v5 — use `sx` prop for one-off styles; create theme overrides for systemic changes.
