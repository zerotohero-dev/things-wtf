# CSS & JavaScript

## Injecting Custom CSS

Place your stylesheet in `docs/stylesheets/` and register it:

```toml title="zensical.toml"
[project]
extra_css = ["stylesheets/extra.css"]
```

Your CSS is loaded after Zensical's own styles, so any rule you define will override the defaults.

### Common CSS Recipes

**Widen the content area:**

```css
/* Increase max content width */
.md-grid {
  max-width: 1400px;
}

/* Or remove the limit entirely */
.md-content__inner {
  max-width: none;
}
```

**Style a specific page (via `.md-content` + page slug class):**

```css
/* Target pages that have a specific class added via front matter */
.page-landing .md-content {
  padding: 0;
}
```

**Override admonition border radius:**

```css
.md-typeset .admonition,
.md-typeset details {
  border-radius: 0; /* sharp corners */
}
```

## Injecting Custom JavaScript

```toml title="zensical.toml"
[project]
extra_javascript = ["javascripts/extra.js"]
```

### Loading Options

For fine-grained control over how scripts load, use the expanded table format:

```toml title="zensical.toml"
# ES Module
[[project.extra_javascript]]
path = "javascripts/app.mjs"
type = "module"

# Async (doesn't block page render)
[[project.extra_javascript]]
path = "javascripts/analytics.js"
async = true

# Deferred (runs after HTML parse)
[[project.extra_javascript]]
path = "javascripts/tooltips.js"
defer = true
```

## The `document$` Observable

!!! danger "Always use `document$`, not `DOMContentLoaded`"
    When [`navigation.instant`](../authoring/navigation.md) is enabled, navigation happens via XHR — the browser never fully reloads the page. `DOMContentLoaded` fires once and never again. The `document$` observable fires on every page render, including instant navigations.

```js title="docs/javascripts/extra.js"
// Runs on every page load AND every instant navigation
document$.subscribe(function () {
  console.log("Page is ready");
  initMyLibrary();
  mountWidgets();
});
```

`document$` is a globally exported RxJS-style observable. You subscribe to it; Zensical calls your callback every time a page finishes rendering.

### Cleaning Up Between Pages

For libraries that attach event listeners or mutate the DOM, clean up before re-initializing:

```js title="docs/javascripts/extra.js"
let myInstance = null;

document$.subscribe(function () {
  if (myInstance) {
    myInstance.destroy();
  }
  myInstance = initMyLibrary(".md-content");
});
```

### Embedding a JS Framework (React / Vue / Svelte)

1. Build your app externally (e.g. `vite build --outDir ../docs/javascripts/`)
2. Create a [custom template](template-overrides.md#custom-page-templates) with a mount point
3. Mount via `document$`:

```js title="docs/javascripts/app.js"
import { createApp } from "https://cdn.jsdelivr.net/npm/vue@3/dist/vue.esm-browser.js";

document$.subscribe(function () {
  const el = document.getElementById("vue-app");
  if (el) {
    createApp({ /* ... */ }).mount(el);
  }
});
```

!!! warning "Font size baseline"
    Zensical sets `html { font-size: 125% }`. Third-party components using `rem` units will render 25% larger. Use explicit `px` values or reset the root font size for your component's container.
