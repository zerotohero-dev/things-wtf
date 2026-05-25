# Languages & Internationalization

## Setting the Site Language

Zensical translates its UI chrome (search placeholder, "Was this page helpful?", footer copy, etc.) into 60+ languages. Set the language once for the entire site:

```toml title="zensical.toml"
[project.theme]
language = "de"  # German
```

HTML5 allows only one language per document, so this sets the canonical language for the whole site.

## Language Selector (Multi-Language Sites)

If your documentation exists in multiple languages as separate deployments, add a language selector to the header:

```toml title="zensical.toml"
[project.extra]
alternate = [
  { name = "English", link = "/en/", lang = "en" },
  { name = "Deutsch", link = "/de/", lang = "de" },
  { name = "日本語",  link = "/ja/", lang = "ja" },
]
```

Each entry requires `name` (display text), `link` (URL), and `lang` (BCP 47 language code).

!!! note
    Zensical does not handle routing between language versions — that's the responsibility of your hosting setup. This setting only renders the switcher UI in the header.

## Custom Translation Overrides

To override specific UI strings while keeping the rest of a language intact, create a custom language partial.

**Step 1 — Create the override file:**

```html+jinja title="overrides/partials/languages/custom.html"
{# Import your base language and the English fallback #}
{% import "partials/languages/de.html" as language %}
{% import "partials/languages/en.html" as fallback %}

{# Define your overrides as a simple mapping #}
{% macro override(key) %}
  {{ {
    "source.file.date.created": "Erstellt am",
    "source.file.date.updated": "Aktualisiert am",
    "search.result.none":       "Keine Ergebnisse für diese Suche"
  }[key] }}
{% endmacro %}

{# Fallback chain: override → language → English #}
{% macro t(key) %}
  {{ override(key) or language.t(key) or fallback.t(key) }}
{% endmacro %}
```

!!! warning "English must always be the final fallback"
    `en` is the source language for all Zensical strings. Always import it as the last fallback.

**Step 2 — Activate the custom language:**

```toml title="zensical.toml"
[project.theme]
language = "custom"
```

## Common Translation Keys

| Key | UI element |
|-----|------------|
| `search.result.none` | No search results message |
| `search.result.one` | "1 result" label |
| `search.result.other` | "N results" label |
| `source.file.date.created` | "Created" in page metadata |
| `source.file.date.updated` | "Updated" in page metadata |
| `footer.next` | "Next" navigation link |
| `footer.previous` | "Previous" navigation link |
| `toc.title` | Table of contents heading |
| `cookies.accept` | Cookie consent accept button |
| `cookies.reject` | Cookie consent reject button |

To find the full list of keys, inspect `partials/languages/en.html` in the Zensical source.

## RTL Support

For right-to-left languages, set the text direction:

```toml title="zensical.toml"
[project.theme]
language  = "ar"
direction = "rtl"
```
