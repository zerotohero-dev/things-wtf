# Plugin Concepts

Headlamp plugins are **TypeScript/JavaScript modules** that extend the frontend UI. They run at runtime in the same JavaScript context as the host application and register capabilities using a registry API.

## What plugins can do

| Capability | Registry function |
|---|---|
| Add sidebar navigation entries | `registerSidebarEntry()` |
| Register new routes / full pages | `registerRoute()` |
| Inject buttons into the app bar | `registerAppBarAction()` |
| Add sections to resource detail views | `registerDetailsViewSection()` |
| Add action buttons to resource detail headers | `registerDetailsViewHeaderAction()` |
| Modify resource table columns | `registerResourceTableColumnsProcessor()` |
| Replace the cluster chooser button | `registerClusterChooserButton()` |
| Replace the app logo (white-label) | `registerAppLogo()` |
| Add a settings panel for the plugin | `registerPluginSettings()` |
| Show/hide sidebar entries conditionally | `registerSidebarEntryFilter()` |
| Pre-populate cluster tokens | token management hooks |

## Plugin loading mechanism

```
1. headlamp-server scans plugins dir on startup
2. Each subdir with main.js is served at /plugins/{name}/main.js
3. Browser fetches the plugin list
4. Frontend dynamically executes each main.js
5. Plugin code calls register*() functions
6. Registry applies changes to the running app immediately
```

!!! warning "No sandboxing"
    Plugins share the host app's JavaScript context, React tree, and Redux store. A plugin with a bug can affect the whole UI. Keep plugins focused and test them before deploying to shared environments.

## Shared dependencies

These packages are provided by the host app. Do **not** add them to your plugin's `package.json` as dependencies — the build toolchain externalizes them automatically, and bundling them would double the code and cause version conflicts.

| Package | Notes |
|---|---|
| `react`, `react-dom` | Core React runtime |
| `@mui/material`, `@mui/lab` | Material UI component library |
| `react-router-dom` | Routing |
| `react-redux` | Redux hooks |
| `lodash` | Utility functions |
| `monaco-editor` | Code editor component |
| `notistack` | Snackbar/toast notifications |
| `@iconify/react` | Icon components |

## Plugin types (loading priority)

As of recent Headlamp versions, plugins are categorized by source. When multiple versions of the same plugin exist, **higher-priority type wins**:

1. **Development plugins** — highest priority; served from the local filesystem during `npm run start`
2. **User-installed plugins** — installed by the user via the Headlamp UI or desktop app
3. **Shipped plugins** — bundled with the container image or installed via `pluginsManager`

This means a development plugin always overrides a production-deployed version of the same name, which is the intended behavior during local development.

## Plugin structure

```
my-plugin/
├── src/
│   └── index.tsx      # entry point — all register*() calls happen here
├── package.json       # name field becomes the plugin's directory name
├── tsconfig.json
└── dist/              # built output (created by npm run build)
    └── main.js        # single output bundle served by headlamp-server
```

## CommonComponents

Headlamp exports a set of pre-styled components from `@kinvolk/headlamp-plugin/lib/CommonComponents` that match the host app's design system. Use these for visual consistency:

| Component | Use for |
|---|---|
| `SectionBox` | Standard card wrapper with title |
| `NameValueTable` | Two-column key/value metadata display |
| `ResourceTable` | Sortable, filterable resource table |
| `ConditionsTable` | Kubernetes conditions array rendering |
| `SectionFilterHeader` | Filter bar above tables |
| `Loader` | Standard loading spinner |
| `InlineError` | Inline error message |
| `Link` | Router-aware link component |
| `StatusLabel` | Colored status badges (Running, Failed, etc.) |
