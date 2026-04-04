# Dual-Site Separation

## Problem

The project has a single `docs/` tree with both public and internal
content (`docs/internal/`). A single Zensical build produces `site/`
which includes everything — internal strategy docs, roadmaps, company
internals — and `site/` is deployed to Cloudflare Pages. There is no
mechanism to prevent internal content from being published.

## Goals

- **Hard separation**: internal content must never be an input to the
  public build, eliminating any possibility of accidental publication.
- **Independent sites**: each site gets its own config, theme identity,
  and serve port for local development.
- **Simple workflow**: one command to build/serve each site.

## Non-Goals

- Shared navigation or cross-linking between public and internal sites.
- Authentication or access control for the internal site (it's local-only).
- CI/CD changes (Cloudflare already deploys from `site/`).

## Solution

### Directory layout

```
things-wtf/
├── docs/                  # Public source (Cloudflare Pages)
├── docs-internal/         # Internal source (local only)
│   ├── index.md           # Internal landing page
│   ├── vks/               # Moved from docs/internal/vks/
│   └── zensical/          # Moved from docs/internal/zensical/
├── site/                  # Public output (committed, deployed)
├── site-internal/         # Internal output (gitignored)
├── zensical.toml          # Public config
└── zensical-internal.toml # Internal config
```

### Config: `zensical-internal.toml`

Minimal config that overrides source/output dirs and identity:

```toml
[project]
site_name = "Internal Wiki"
site_description = "Internal documentation — not for publication."
docs_dir = "docs-internal"
site_dir = "site-internal"
```

Theme and feature settings are copied from the public config, with
an accent color change (e.g. deep-purple or amber) so the two sites
are visually distinct at a glance.

### Makefile targets

```makefile
.PHONY: serve serve-internal build build-internal

serve:
	zensical serve

serve-internal:
	zensical serve -f zensical-internal.toml -a localhost:8001

build:
	zensical build

build-internal:
	zensical build -f zensical-internal.toml
```

### Gitignore additions

```
site-internal/
docs-internal/
```

Both `site-internal/` (build output) and `docs-internal/` (source)
are gitignored since internal content must never reach the remote.

### Migration

Move `docs/internal/*` → `docs-internal/`, preserving structure.
The internal site needs its own `index.md` as the doc root landing
page. The `docs/internal/` directory is removed after migration.

## Verification

- `zensical build` produces `site/` with no internal content.
- `zensical build -f zensical-internal.toml` produces `site-internal/`.
- `grep -r "internal" site/` returns no hits from internal docs.
- Both sites serve independently on different ports.
- `git status` never shows `docs-internal/` or `site-internal/` files.

## Error Cases

- **Forgotten gitignore**: if `docs-internal/` is committed, internal
  content could leak via repo access (even if not in the site build).
  Mitigation: add both dirs to `.gitignore` as the first task.
- **Wrong config flag**: running `zensical build` without `-f` always
  builds the public site — safe by default.
