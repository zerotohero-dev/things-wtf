# Configuration

All Zensical configuration lives in `zensical.toml`. Every setting is nested under the `[project]` scope.

!!! info "mkdocs.yml is also supported"
    For projects migrating from Material for MkDocs, `mkdocs.yml` is fully supported as a config format. Both formats are always supported — TOML is the native Zensical format going forward.

## Minimal Config

```toml title="zensical.toml"
[project]
site_name = "My Docs"
site_url  = "https://example.com/"

[project.theme]
name = "zensical"
```

## Top-Level Settings

| Key | Description | Required? |
|-----|-------------|-----------|
| `site_name` | Site title in `<title>` and page headers | **Yes** |
| `site_url` | Canonical URL; required for instant navigation and sitemap | Recommended |
| `site_description` | Meta description for SEO and social sharing | No |
| `site_author` | Author name in HTML meta | No |
| `docs_dir` | Source Markdown directory (default: `docs`) | No |
| `site_dir` | Build output directory (default: `site`) | No |
| `extra_css` | List of CSS files to inject (relative to `docs_dir`) | No |
| `extra_javascript` | List of JS files to inject | No |

## Injecting Assets

Place asset files inside your `docs/` directory, then register them:

```
docs/
├─ stylesheets/
│  └─ extra.css
└─ javascripts/
   └─ extra.js
```

```toml title="zensical.toml"
[project]
extra_css        = ["stylesheets/extra.css"]
extra_javascript = ["javascripts/extra.js"]
```

## JavaScript Loading Options

Use the expanded table format to control how each script is loaded:

```toml title="zensical.toml"
# Load as ES module
[[project.extra_javascript]]
path = "javascripts/app.mjs"
type = "module"

# Load asynchronously
[[project.extra_javascript]]
path = "javascripts/analytics.js"
async = true

# Defer execution
[[project.extra_javascript]]
path = "javascripts/widgets.js"
defer = true
```

## Equivalent mkdocs.yml

=== "zensical.toml"

    ```toml
    [project]
    site_name = "My Docs"
    site_url  = "https://example.com/"
    extra_css = ["stylesheets/extra.css"]
    ```

=== "mkdocs.yml"

    ```yaml
    site_name: My Docs
    site_url: https://example.com/
    extra_css:
      - stylesheets/extra.css
    ```
