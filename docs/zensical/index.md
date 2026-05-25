---
title: "Zensical"
---

## Master Zensical

**An advanced user guide to getting the most out of Zensical** — themes, full customization, admonitions, template overrides, and the limits of what you can build.

This guide assumes you're using Zensical as an end-user (not a contributor). It covers everything from your first `zensical new` command to overriding MiniJinja partials and creating brand-new admonition types.

---

## What You'll Learn

<div class="grid cards" markdown>

- :lucide-rocket: **Get Started**

    Install Zensical, scaffold a project, and understand the `zensical.toml` configuration format.

    [→ Installation](get-started/installation.md)

- :lucide-palette: **Themes**

    Switch variants, configure light/dark palettes, swap fonts, and customize colors via CSS variables.

    [→ Theme Variants](themes/variants.md)

- :lucide-paintbrush: **Customization**

    Inject CSS and JavaScript, hook into the `document$` observable, and override templates with MiniJinja.

    [→ CSS & JS](customization/css-and-js.md)

- :lucide-file-text: **Authoring**

    Use every admonition type, create custom call-out types, configure navigation features, and enable extensions.

    [→ Admonitions](authoring/admonitions.md)

- :lucide-layers: **Advanced**

    Multi-language docs, custom translation overrides, and a ranked map of every customization layer.

    [→ Flexibility Summary](advanced/flexibility.md)

</div>

---

!!! tip "Coming from Material for MkDocs?"
    Zensical is built by the same team. The HTML structure is identical in both theme variants, so your existing CSS and JS customizations will work. Configuration moves from `mkdocs.yml` into `zensical.toml` (everything nested under `[project]`), but `mkdocs.yml` is also supported as a migration path.
