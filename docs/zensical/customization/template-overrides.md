# Template Overrides

Zensical uses **MiniJinja** — a Rust-based template engine with Jinja2-compatible syntax — to render the HTML scaffold of your site. You can override any part of that scaffold without modifying Zensical itself.

## Setting Up `custom_dir`

```toml title="zensical.toml"
[project.theme]
custom_dir = "overrides"   # path relative to zensical.toml
```

Any file in `overrides/` that matches a path in Zensical's internal theme file system will **replace** that file. Files with no match are treated as new additions (e.g. custom templates).

## Theme File Structure

Key files you'll interact with:

```
theme/
├─ main.html          ← extends base.html; your primary override target
├─ base.html          ← defines all named blocks
├─ 404.html           ← error page
└─ partials/
   ├─ header.html
   ├─ footer.html
   ├─ nav.html
   ├─ toc.html
   ├─ search/
   │  └─ result.html
   └─ languages/
      ├─ en.html
      └─ *.html
```

## Overriding Blocks

The cleanest approach — override a named block in `main.html` without touching the rest. Use `{{ super() }}` to include the original content alongside your additions.

```html+jinja title="overrides/main.html"
{% extends "main.html" %}

{# Announcement banner #}
{% block announce %}
  <div class="md-banner">
    🚀 Version 2.0 released!
    <a href="/changelog">See what's new →</a>
  </div>
{% endblock %}

{# Append scripts without removing Zensical's own #}
{% block scripts %}
  {{ super() }}
  <script src="{{ base_url }}/javascripts/my-init.js"></script>
{% endblock %}

{# Inject meta tags into <head> #}
{% block extrahead %}
  <meta property="og:image" content="{{ config.site_url }}assets/social.png">
{% endblock %}
```

### Available Blocks

| Block | Controls |
|-------|----------|
| `announce` | Top announcement / banner bar |
| `header` | Entire site header |
| `hero` | Optional hero section (homepage) |
| `tabs` | Top-level navigation tabs |
| `content` | Main page content area |
| `footer` | Site footer |
| `scripts` | `<script>` tags before `</body>` |
| `extrahead` | Extra tags inside `<head>` |
| `analytics` | Analytics snippet slot |
| `outdated` | Version outdated warning |

## Overriding Partials

Partials are reusable sub-templates included by `main.html`. Override them by placing a matching file at `overrides/partials/<name>.html`.

**Example — extended footer:**

```html+jinja title="overrides/partials/footer.html"
{% include "partials/footer.html" %}
<div class="my-footer-extra">
  Built with Zensical ·
  <a href="/privacy">Privacy</a>
</div>
```

**Example — custom search result partial:**

```html+jinja title="overrides/partials/search/result.html"
{% extends "partials/search/result.html" %}
{% block result_meta %}
  {{ super() }}
  <span class="result-section">{{ doc.section }}</span>
{% endblock %}
```

!!! warning "MiniJinja limitation"
    MiniJinja does not support calling arbitrary Python functions — it is built in Rust. If you need a Python Markdown extension that calls a Python function from a template, check whether an equivalent MiniJinja filter or test exists. The Zensical team plans a component system to address this in a future release.

## Custom Page Templates { #custom-page-templates }

Create a new `.html` file in `overrides/` and assign it to any Markdown page via front matter.

**1. Create the template:**

```html+jinja title="overrides/landing.html"
{% extends "base.html" %}

{% block content %}
  <section class="landing-hero">
    <h1>{{ page.title }}</h1>
    {{ page.content }}
  </section>
  <div id="app-mount"></div>
{% endblock %}

{% block scripts %}
  {{ super() }}
  <script type="module" src="{{ base_url }}/javascripts/landing-app.js"></script>
{% endblock %}
```

**2. Assign it in the page's front matter:**

```yaml title="docs/index.md (front matter)"
---
template: landing.html
hide:
  - navigation
  - toc
---

# Welcome to My Project

Your landing page content here.
```

## Custom 404 Page

```html+jinja title="overrides/404.html"
{% extends "main.html" %}

{% block content %}
  <div class="md-content">
    <article class="md-content__inner">
      <h1>404 — Not Found</h1>
      <p>The page you're looking for doesn't exist.</p>
      <a href="{{ config.site_url }}" class="md-button md-button--primary">
        Go home
      </a>
    </article>
  </div>
{% endblock %}
```

## MiniJinja Template Context

These variables are available in all templates:

| Variable | Type | Contents |
|----------|------|----------|
| `config` | object | Full Zensical config (site_name, site_url, etc.) |
| `page` | object | Current page (title, content, meta, url) |
| `nav` | object | Full navigation tree |
| `base_url` | string | Relative base URL for asset links |
| `extra` | object | Contents of `[project.extra]` in config |

!!! note "Accessing page metadata"
    Front matter values are available under `page.meta`:

    ```html+jinja
    {% if page.meta.custom_field %}
      <span>{{ page.meta.custom_field }}</span>
    {% endif %}
    ```
