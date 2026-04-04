# Scaffold & Dev Mode

## Create a new plugin

Run this from your **projects directory** — not inside the Headlamp repo:

```bash
npx --yes @kinvolk/headlamp-plugin create my-plugin
cd my-plugin
npm install
```

This scaffolds:

```
my-plugin/
├── src/
│   └── index.tsx       # your plugin entry point
├── package.json
├── tsconfig.json
└── README.md
```

## Write your first plugin

Replace `src/index.tsx` with something meaningful. This example adds a sidebar section and a route:

```typescript title="src/index.tsx"
import {
  registerSidebarEntry,
  registerRoute,
} from '@kinvolk/headlamp-plugin/lib';
import { SectionBox } from '@kinvolk/headlamp-plugin/lib/CommonComponents';
import { Typography } from '@mui/material';

// Add sidebar entry
registerSidebarEntry({
  parent: null,         // null = top-level; use a parent name to nest
  name:   'my-section',
  label:  'My Section',
  url:    '/my-section',
  icon:   'mdi:package-variant',   // any Iconify icon
});

// Register the route
registerRoute({
  path:      '/my-section',
  sidebar:   'my-section',         // highlights the sidebar entry when active
  component: () => (
    <SectionBox title="My Section">
      <Typography>Hello from a Headlamp plugin!</Typography>
    </SectionBox>
  ),
});
```

## Start dev mode

```bash
npm run start
```

This:

1. Builds the plugin bundle
2. Writes it to `~/.config/Headlamp/plugins/my-plugin/main.js`
3. Watches for file changes and rebuilds automatically

With `watchPlugins: true` in Headlamp, the server detects the directory change and the browser reloads the plugin. No Headlamp restart needed.

!!! tip "Desktop app"
    The Headlamp desktop app detects development plugins automatically — no port-forward or `watchPlugins` setting needed.

## Development workflow

```
edit src/index.tsx
      │
      ▼ (automatic)
npm run start rebuilds
      │
      ▼ (automatic with watchPlugins: true)
headlamp-server reloads plugin
      │
      ▼ (automatic)
browser refreshes
```

### Troubleshooting

- **Plugin not appearing**: check that `npm run start` is running without errors; verify the plugin directory at `~/.config/Headlamp/plugins/my-plugin/main.js` exists
- **Changes not reflecting**: ensure you have only one Headlamp tab open; multiple tabs can interfere with hot-reload
- **Build errors**: run `npm run tsc` to see TypeScript errors; `npm run lint` for lint errors
- **Stale plugin**: delete the plugin from `~/.config/Headlamp/plugins/my-plugin/` and rerun `npm run start`

## Quality tooling

```bash
npm run format      # Prettier
npm run lint        # ESLint
npm run lint-fix    # auto-fix ESLint issues
npm run tsc         # TypeScript type check (no emit)
npm run test        # Jest unit tests
```

## Build for production

```bash
npm run build
# → dist/main.js

npm run package
# → my-plugin-0.1.0.tar.gz
# Tarball checksum printed to stdout
```

The tarball can be:

- Extracted into an in-cluster plugin directory
- Published to Artifact Hub
- Used with `pluginsManager` in the Helm chart

See [Deploying In-Cluster](deploying.md) for the full deployment options.

## Example: app bar action with click handler

```typescript title="src/index.tsx"
import { registerAppBarAction } from '@kinvolk/headlamp-plugin/lib';
import { Button } from '@mui/material';

function StatusButton() {
  return (
    <Button
      variant="outlined"
      size="small"
      onClick={() => alert('Plugin action!')}
      sx={{ mx: 1 }}
    >
      My Action
    </Button>
  );
}

registerAppBarAction(<StatusButton />);
```

## Example: nested sidebar entry

```typescript
// parent section
registerSidebarEntry({
  parent: null,
  name:   'security',
  label:  'Security',
  url:    '/security',
  icon:   'mdi:shield-check',
});

// child under "security"
registerSidebarEntry({
  parent: 'security',   // references the parent's "name"
  name:   'spiffe',
  label:  'SPIFFE Entries',
  url:    '/security/spiffe',
  icon:   'mdi:key-chain',
});

registerRoute({
  path:      '/security/spiffe',
  sidebar:   'spiffe',
  component: SpiffeEntryList,
});
```
