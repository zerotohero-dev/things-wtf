# Fonts

Zensical integrates directly with **Google Fonts**. The regular (body) and monospaced (code) typefaces are configured independently.

## Google Fonts

```toml title="zensical.toml"
[project.theme]
font.text = "Geist"           # body copy, headings
font.code = "JetBrains Mono"  # code blocks
```

Pass any valid Google Font name as the value. Zensical will generate the correct `<link>` tag and inject it into the `<head>`.

## Disable Google Fonts

To fall back to system fonts — for data privacy compliance or offline use:

```toml title="zensical.toml"
[project.theme]
font = false
```

## Self-Hosted / Custom Fonts

Add a `@font-face` declaration in your `extra.css` and override the CSS variable:

```css title="docs/stylesheets/extra.css"
@font-face {
  font-family: "MyBrand";
  src: url("../fonts/mybrand.woff2") format("woff2");
  font-weight: 400;
  font-display: swap;
}

@font-face {
  font-family: "MyBrand";
  src: url("../fonts/mybrand-bold.woff2") format("woff2");
  font-weight: 700;
  font-display: swap;
}

:root {
  --md-text-font: "MyBrand";
}
```

Place your font files in `docs/fonts/` so they're included in the build output.

!!! warning "Font size baseline"
    Zensical sets `html { font-size: 125% }` (20px). Third-party libraries that use `rem`-based sizing will render 25% larger than expected. Fix this by setting explicit `px` values or adjusting the root font size in your CSS:

    ```css
    /* Reset to browser default (16px base) */
    :root { font-size: 100%; }
    ```

## Monospace Font for Code

The code font applies to all fenced code blocks and inline code. Popular choices:

| Font | Style |
|------|-------|
| `JetBrains Mono` | Developer-friendly, ligatures |
| `Fira Code` | Ligature-rich, open source |
| `Cascadia Code` | Microsoft, clean |
| `IBM Plex Mono` | Editorial, technical |
| `Source Code Pro` | Adobe, reliable |
