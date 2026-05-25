# Flexibility Summary

This page maps every layer of Zensical customization from lightest to deepest, so you know exactly which mechanism to reach for.

## Customization Layers

| Layer | Mechanism | What You Can Change |
|-------|-----------|---------------------|
| **1 · Config** | `zensical.toml` settings | Colors, fonts, logo, icons, language, feature flags, extensions, navigation |
| **2 · CSS** | `extra_css` + CSS variables | Any visual property — colors, spacing, layout, typography, animations, content width |
| **3 · JavaScript** | `extra_javascript` + `document$` | Behavior, third-party widgets, interactive features, SPA-compatible hooks |
| **4 · Block overrides** | `custom_dir` + `{% block %}` | Replace or extend named HTML sections (header, footer, announce, scripts, etc.) |
| **5 · Partial overrides** | `overrides/partials/*.html` | Replace individual sub-templates (nav, TOC, header, footer, search results, language strings) |
| **6 · Custom templates** | New `.html` in `custom_dir` + front matter `template:` | Completely custom page layouts with full HTML structure control, per-page |
| **7 · Custom icons** | `.icons/` directory + emoji options | Add entire SVG icon sets; use any icon in config, Markdown, and templates |
| **8 · Custom admonitions** | CSS targeting `.admonition.<type>` | Create new call-out types with custom color, icon, and title style |
| **9 · Localization** | `language = "custom"` + partial macro | Override any UI string, with a full language → fallback chain |

---

## Decision Guide

**"I just want to change the colors."**
→ Layer 1 (config palette) or Layer 2 (CSS variables if you need brand-specific hex values).

**"I want a custom font."**
→ Layer 1 for Google Fonts. Layer 2 (`@font-face` in `extra.css`) for self-hosted or custom fonts.

**"I need to embed a third-party widget on every page."**
→ Layer 3: add a JS file, subscribe to `document$`, mount your widget.

**"I want a custom banner at the top of every page."**
→ Layer 4: override the `announce` block in `overrides/main.html`.

**"I need a completely custom homepage with a hero section."**
→ Layer 6: create `overrides/landing.html`, assign it via `template: landing.html` in front matter, hide navigation and TOC.

**"I want to add a custom admonition type for release notes."**
→ Layer 8: CSS + a type keyword in your Markdown.

**"My project is in German but I want to change two specific UI strings."**
→ Layer 9: create `overrides/partials/languages/custom.html` and set `language = "custom"`.

---

## What You Can't Change (Current Limitations)

!!! warning "MiniJinja does not call Python"
    MiniJinja (the template engine) is built in Rust and does not support calling arbitrary Python functions. If a Python Markdown extension needs to invoke Python from a template, check whether a MiniJinja filter achieves the same result. The Zensical team plans a component system to eventually replace this boundary.

!!! info "Symbolic links"
    Zensical follows symbolic links only within directories that are already part of the build. Links that point outside the build tree are not followed (security restriction).

!!! note "Theme component system (future)"
    A component system is planned that will make it easier to build and share entirely new theme variants — going beyond overrides to defining new first-class visual systems.

---

## Embedding a Full App

The combination of Layers 2–6 lets you embed a complete JavaScript framework app inside a Zensical page:

1. **Build externally** — compile your React/Vue/Svelte app into a bundle, output to `docs/javascripts/`
2. **Create a custom template** — `overrides/app.html` extends `base.html`, adds a `<div id="app-mount">`
3. **Assign via front matter** — `template: app.html` on the target page
4. **Mount via `document$`** — hook into Zensical's observable to initialize on each navigation

This pattern is used for interactive demos, dashboards, and configuration wizards embedded inline in documentation.

---

## Quick Reference Card

```
zensical.toml                     ← colors, fonts, features, extensions
docs/stylesheets/extra.css        ← CSS variable overrides, layout tweaks
docs/javascripts/extra.js         ← document$.subscribe(fn)
overrides/main.html               ← {% block announce %}, {% block scripts %}
overrides/partials/footer.html    ← footer partial override
overrides/landing.html            ← custom template (any name)
overrides/.icons/<set>/*.svg      ← custom icon set
overrides/partials/languages/     ← translation overrides
```
