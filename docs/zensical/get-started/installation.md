# Installation

Zensical requires **Python ≥ 3.10**.

## Install

```sh
pip install zensical
```

## Create a New Project

```sh
zensical new my-docs
cd my-docs
```

This scaffolds the minimal project structure:

```
my-docs/
├─ docs/
│  └─ index.md
└─ zensical.toml
```

## Local Preview

```sh
zensical serve
```

Opens a live-reloading dev server at `http://localhost:8000`. The page auto-refreshes on any file change.

!!! warning "serve is not production-grade"
    `zensical serve` is for local development only. Don't use it to serve a live site.

## Build for Production

```sh
zensical build
```

Outputs a static site to the `site/` directory (or whatever `site_dir` is set to in your config). Deploy the contents of that directory to any static host — GitHub Pages, Netlify, Cloudflare Pages, S3, etc.

## Upgrading

```sh
pip install --upgrade zensical
```

!!! note "Config stability"
    Zensical is still on `0.0.x` versioning, meaning the internal API changes frequently. User-facing configuration is kept stable, and any breaking changes will come with automatic migration tooling.
