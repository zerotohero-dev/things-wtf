# Colors

## Color Schemes

Zensical has two built-in color schemes:

- `default` — light mode
- `slate` — dark mode

### Single palette (dark only)

```toml title="zensical.toml"
[[project.theme.palette]]
scheme      = "slate"
primary     = "deep purple"
accent      = "cyan"
toggle.icon = "lucide/moon"
toggle.name = "Switch to light mode"
```

### Light + dark toggle

```toml title="zensical.toml"
[[project.theme.palette]]
scheme      = "default"
primary     = "indigo"
accent      = "cyan"
toggle.icon = "lucide/sun"
toggle.name = "Switch to dark mode"

[[project.theme.palette]]
scheme      = "slate"
primary     = "deep purple"
accent      = "cyan"
toggle.icon = "lucide/moon"
toggle.name = "Switch to light mode"
```

!!! note
    `theme.palette` is a TOML array (`[[...]]`), allowing multiple entries for the toggle chain.

### Auto-switch from OS preference

```toml title="zensical.toml"
[[project.theme.palette]]
media       = "(prefers-color-scheme: light)"
scheme      = "default"
toggle.icon = "lucide/sun"
toggle.name = "Switch to dark mode"

[[project.theme.palette]]
media       = "(prefers-color-scheme: dark)"
scheme      = "slate"
toggle.icon = "lucide/moon"
toggle.name = "Switch to light mode"
```

Zensical listens for OS-level theme changes and switches automatically without a page reload.

## Built-in Primary Colors

The following values are valid for `primary` and `accent`:

`red` · `pink` · `purple` · `deep purple` · `indigo` · `blue` · `light blue` · `cyan` · `teal` · `green` · `light green` · `lime` · `yellow` · `amber` · `orange` · `deep orange` · `brown` · `grey` · `blue grey` · `black` · `white`

## Custom Colors via CSS Variables

Zensical implements all colors as CSS custom properties. To use brand-specific colors, override the variables in your `extra.css`:

```css title="docs/stylesheets/extra.css"
/* Dark mode overrides */
[data-md-color-scheme="slate"] {
  --md-primary-fg-color:        #7c3aed;
  --md-primary-fg-color--light: #9f67ff;
  --md-primary-fg-color--dark:  #5b21b6;
  --md-accent-fg-color:         #06b6d4;
}

/* Light mode overrides */
[data-md-color-scheme="default"] {
  --md-primary-fg-color:        #5b21b6;
  --md-accent-fg-color:         #0891b2;
}
```

You must also set `primary: custom` in your palette entry to tell Zensical not to override your values:

```toml title="zensical.toml"
[[project.theme.palette]]
scheme  = "slate"
primary = "custom"
accent  = "custom"
```

### Key CSS Variables

| Variable | Controls |
|----------|----------|
| `--md-primary-fg-color` | Header background, sidebar active state, links |
| `--md-primary-fg-color--light` | Hover/lighter variant of primary |
| `--md-primary-fg-color--dark` | Darker variant of primary |
| `--md-accent-fg-color` | Buttons, interactive elements, hover states |
| `--md-default-bg-color` | Main page background |
| `--md-default-fg-color` | Body text |
| `--md-code-bg-color` | Code block backgrounds |
| `--md-typeset-color` | Typeset body text |
| `--md-typeset-a-color` | Link color in body text |

!!! tip "Finding all variables"
    The full list of CSS variables is in the Zensical source under `src/templates/assets/stylesheets/`. You can also inspect the computed styles in your browser DevTools on any Zensical site.
