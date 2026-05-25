# Navigation

## Feature Flags

Enable navigation features via the `features` list in your theme config:

```toml title="zensical.toml"
[project.theme]
features = [
  "navigation.instant",    # SPA-style transitions (XHR, no reload)
  "navigation.tabs",       # top-level sections as header tabs
  "navigation.sections",   # expand top-level sections in sidebar
  "navigation.expand",     # auto-expand active section
  "navigation.top",        # back-to-top button
  "navigation.footer",     # prev/next page links in footer
  "toc.integrate",         # merge table of contents into sidebar
  "toc.follow",            # auto-scroll TOC to current heading
  "search.highlight",      # highlight search terms on the result page
  "content.code.copy",     # copy button on all code blocks
  "content.code.annotate", # numbered code annotations
  "content.tabs.link",     # sync content tabs with same label across page
]
```

### Feature Reference

| Feature | Effect |
|---------|--------|
| `navigation.instant` | Clicks on internal links use XHR — no full page reload. Behaves like an SPA. Requires `site_url`. |
| `navigation.tabs` | Renders top-level nav sections as horizontal tabs in the header. |
| `navigation.sections` | Shows top-level sections as group headers in the sidebar rather than collapsible items. |
| `navigation.expand` | Auto-expands the active section in the sidebar. |
| `navigation.top` | Shows a "Back to top" button when the user scrolls up. |
| `navigation.footer` | Adds "Previous" / "Next" links at the bottom of every page. |
| `toc.integrate` | Merges the in-page TOC into the left sidebar instead of showing it on the right. |
| `toc.follow` | The TOC sidebar auto-scrolls to keep the active heading visible. |
| `search.highlight` | When navigating to a search result, highlights the matching terms on the target page. |
| `content.code.copy` | Adds a copy-to-clipboard button to every fenced code block. |
| `content.code.annotate` | Enables `# (1)!` annotation syntax in code blocks. |
| `content.tabs.link` | Content tabs with the same label are synced — selecting one selects all matching. |

!!! warning "Instant navigation requires `site_url`"
    `navigation.instant` relies on the generated `sitemap.xml`. Without `site_url` set, the sitemap will be empty and instant navigation will not function.

## Hiding Elements Per Page

Use front matter to suppress the sidebar, TOC, breadcrumb, or any other element on a specific page:

```yaml
---
hide:
  - navigation   # hide left sidebar
  - toc          # hide right table of contents
  - path         # hide breadcrumb navigation
---
```

This is especially useful for full-width landing pages and custom layouts.

## Instant Previews

Instant previews show a hover popup of a linked page without navigating to it. Enable them for specific pages or sections:

```toml title="zensical.toml"
[[project.markdown_extensions.zensical.extensions.preview.configurations]]
targets.include = [
  "authoring/*",
  "customization.md",
]
```

You can also configure source pages (pages whose links trigger previews) and target pages (the destinations shown in the preview) independently:

```toml title="zensical.toml"
[[project.markdown_extensions.zensical.extensions.preview.configurations]]
sources.include = ["index.md"]
targets.include = ["get-started/*"]
```

## Navigation Structure in Config

Define your site navigation explicitly in `zensical.toml`:

```toml title="zensical.toml"
[project.nav]
"Home" = "index.md"

[[project.nav."Guide"]]
"Installation" = "guide/installation.md"
"Setup"        = "guide/setup.md"

[[project.nav."Reference"]]
"API"    = "reference/api.md"
"Config" = "reference/config.md"
```

Sections can be arbitrarily nested. An `index.md` inside a section is used as the section overview page.

!!! tip
    If you omit `nav` entirely, Zensical auto-generates navigation from the `docs/` directory structure.
