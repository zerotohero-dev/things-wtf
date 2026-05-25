# Admonitions

Admonitions (call-outs) let you highlight side content — notes, tips, warnings, examples — without interrupting the reading flow.

## Configuration

Enable admonitions and related extensions:

```toml title="zensical.toml"
[project.markdown_extensions.admonition]
[project.markdown_extensions.pymdownx.details]     # collapsible blocks
[project.markdown_extensions.pymdownx.superfences]  # nested content
```

## Basic Syntax

A block starts with `!!!`, followed by the **type keyword**, then content indented by 4 spaces:

```markdown
!!! note

    Content goes here. Supports full **Markdown**, including lists,
    code blocks, and nested admonitions (with superfences enabled).
```

!!! note

    Content goes here. Supports full **Markdown**, including lists,
    code blocks, and nested admonitions (with superfences enabled).

## Custom Title

Pass a quoted string after the type to override the default title:

```markdown
!!! tip "Did you know?"

    You can override the title of any admonition.
```

!!! tip "Did you know?"

    You can override the title of any admonition.

## Remove the Title Bar

Pass an empty string `""` to render a title-less admonition:

```markdown
!!! warning ""

    No title bar — just the colored border and background.
```

!!! warning ""

    No title bar — just the colored border and background.

## Collapsible Blocks

Requires `pymdownx.details`. Use `???` for collapsed by default, `???+` for expanded by default:

```markdown
??? note "Click to expand"

    This admonition starts collapsed.

???+ tip "Expanded by default"

    This one starts open but can be collapsed.
```

??? note "Click to expand"

    This admonition starts collapsed.

???+ tip "Expanded by default"

    This one starts open but can be collapsed.

## Inline Blocks

Float an admonition alongside body text using `inline` or `inline end`:

```markdown
!!! tip inline end "Floats right"

    Use `inline end` to float to the right of the following text.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent interdum
augue vel nisi sodales, eget tincidunt arcu condimentum.
```

!!! tip inline end "Pro tip"

    Use `inline end` to float this to the right.

When an admonition is floated, the surrounding text wraps around it naturally. This works well for short call-outs next to descriptive paragraphs.

## Nested Content (superfences)

With `pymdownx.superfences`, you can nest code blocks and even other admonitions:

````markdown
!!! example "With nested code"

    Here's a Python example:

    ```python
    def greet(name: str) -> str:
        return f"Hello, {name}!"
    ```

    And a nested warning:

    !!! warning

        Watch out for edge cases with empty strings.
````

!!! example "With nested code"

    Here's a Python example:

    ```python
    def greet(name: str) -> str:
        return f"Hello, {name}!"
    ```

    And a nested warning:

    !!! warning

        Watch out for edge cases with empty strings.

## All Built-in Types

| Type | Aliases | Color |
|------|---------|-------|
| `note` | — | Blue |
| `abstract` | `summary`, `tldr` | Light blue |
| `info` | `todo` | Cyan |
| `tip` | `hint`, `important` | Teal/green |
| `success` | `check`, `done` | Green |
| `question` | `help`, `faq` | Light green |
| `warning` | `caution`, `attention` | Orange |
| `failure` | `fail`, `missing` | Red-orange |
| `danger` | `error` | Red |
| `bug` | — | Pink/red |
| `example` | — | Purple |
| `quote` | `cite` | Grey |

!!! note
    All aliases render identically to the canonical type.

## Custom Admonition Types { #custom-types }

Create a completely new type by targeting `.admonition.<type>` in CSS. Zensical applies the type name as a class on the wrapper element.

**Step 1 — Define the icon variable and colors in CSS:**

```css title="docs/stylesheets/extra.css"
/* SVG icon as data URI, or reference a bundled icon */
:root {
  --md-admonition-icon--release: url(
    'data:image/svg+xml;charset=utf-8,\
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">\
    <path fill="currentColor" d="M12 2L2 7l10 5 10-5-10-5..."/>\
    </svg>'
  );
}

/* Border color for the admonition box */
.md-typeset .admonition.release,
.md-typeset details.release {
  border-color: #ff6b35;
}

/* Title bar background and text color */
.md-typeset .release > .admonition-title,
.md-typeset .release > summary {
  background-color: rgba(255, 107, 53, 0.1);
  color: #ff6b35;
}

/* Icon in the title bar */
.md-typeset .release > .admonition-title::before,
.md-typeset .release > summary::before {
  background-color: #ff6b35;
  -webkit-mask-image: var(--md-admonition-icon--release);
          mask-image: var(--md-admonition-icon--release);
}
```

**Step 2 — Use it in Markdown:**

```markdown
!!! release "v2.1.0 — April 2025"

    Released on 2025-04-01. Includes new dark mode and 40+ bug fixes.
    See the full changelog for details.
```

## Overriding Admonition Icons { #icon-overrides }

Replace any built-in type's icon with any bundled icon:

```toml title="zensical.toml"
[project.theme.icon.admonition]
note     = "octicons/tag-16"
tip      = "lucide/lightbulb"
warning  = "octicons/alert-16"
danger   = "lucide/zap"
info     = "octicons/info-16"
success  = "octicons/check-16"
question = "octicons/question-16"
failure  = "octicons/x-circle-16"
bug      = "fontawesome/solid/robot"
example  = "octicons/beaker-16"
quote    = "octicons/quote-16"
abstract = "octicons/checklist-16"
```

!!! tip
    You can also use icons from custom icon sets here — as long as the set is registered in `options.custom_icons`.
