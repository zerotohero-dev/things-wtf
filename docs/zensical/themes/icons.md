# Logo & Icons

## Built-in Icon Library

Zensical ships with over **10,000 icons** ready to use in configuration, Markdown content, and templates:

| Set | Prefix | Example |
|-----|--------|---------|
| Lucide | `lucide/` | `lucide/book-open` |
| Material | `material/` | `material/home` |
| Octicons | `octicons/` | `octicons/tag-16` |
| FontAwesome Solid | `fontawesome/solid/` | `fontawesome/solid/check` |
| FontAwesome Regular | `fontawesome/regular/` | `fontawesome/regular/bell` |
| FontAwesome Brands | `fontawesome/brands/` | `fontawesome/brands/github` |
| Simple Icons | `simple/` | `simple/python` |

## Setting the Logo

### From an image file

```toml title="zensical.toml"
[project.theme]
logo    = "assets/logo.svg"   # relative to docs/
favicon = "assets/favicon.png"
```

### From a bundled icon

```toml title="zensical.toml"
[project.theme]
logo = "lucide/book-open"
```

### Custom logo link

By default the logo links to `site_url`. Override it:

```toml title="zensical.toml"
[project.theme]
logo_url = "https://your-main-site.com"
```

## Using Icons in Markdown

Enable the emoji extension (required for icon shortcodes):

```toml title="zensical.toml"
[project.markdown_extensions.pymdownx.emoji]
emoji_index     = "zensical.extensions.emoji.twemoji"
emoji_generator = "zensical.extensions.emoji.to_svg"
```

Then reference icons in Markdown using the `:set-name:` shortcode syntax:

```markdown
:lucide-rocket: Launch docs

:octicons-mark-github-16: View on GitHub

:fontawesome-brands-python: Python project
```

!!! note "Icon shortcode format"
    Use hyphens to separate the set prefix and icon name in Markdown shortcodes, replacing `/` with `-`:
    `lucide/book-open` → `:lucide-book-open:`

## Adding Custom Icon Sets

You can add entire third-party SVG icon sets (e.g. Bootstrap Icons, Heroicons).

**1. Create the directory structure:**

```
overrides/
└─ .icons/
   └─ bootstrap/
      └─ *.svg        ← individual SVG files
```

**2. Register the icon path:**

```toml title="zensical.toml"
[project.markdown_extensions.pymdownx.emoji]
emoji_index     = "zensical.extensions.emoji.twemoji"
emoji_generator = "zensical.extensions.emoji.to_svg"
options.custom_icons = ["overrides/.icons"]
```

**3. Use in Markdown:**

```markdown
:bootstrap-star-fill:
:bootstrap-arrow-right-circle:
```

!!! tip "SVG requirements"
    Custom SVG icons should have a `viewBox` attribute and no hardcoded `fill` or `stroke` colors — use `currentColor` so they inherit the theme color.
