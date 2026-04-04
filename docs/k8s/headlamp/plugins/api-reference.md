# Plugin API Reference

All functions are imported from `@kinvolk/headlamp-plugin/lib` unless noted.

---

## registerAppBarAction

```typescript
registerAppBarAction(component: React.ReactElement): void
```

Inject a React component into the top navigation bar. Renders alongside the built-in cluster selector, notifications, and settings icon.

**Use for:** status indicators, quick-launch buttons, cluster switchers, notification badges.

```typescript
import { registerAppBarAction } from '@kinvolk/headlamp-plugin/lib';
import { Chip } from '@mui/material';

registerAppBarAction(<Chip label="My Plugin" size="small" color="primary" />);
```

---

## registerSidebarEntry

```typescript
registerSidebarEntry(config: {
  parent: string | null;   // null for top-level; parent name for nesting
  name: string;            // unique identifier
  label: string;           // display text
  url: string;             // route this entry links to
  icon?: string;           // Iconify icon string, e.g. 'mdi:kubernetes'
  subtitle?: string;       // shown below label in expanded view
}): void
```

Add a navigation item to the left sidebar. Use `parent: null` for top-level entries; set `parent` to another entry's `name` to nest beneath it.

```typescript
registerSidebarEntry({
  parent: null,
  name:   'observability',
  label:  'Observability',
  url:    '/observability',
  icon:   'mdi:chart-line',
});
```

---

## registerRoute

```typescript
registerRoute(config: {
  path: string;                         // URL path pattern (supports :params)
  component: React.ComponentType<any>;  // page component
  sidebar?: string;                     // sidebar entry name to highlight
  name?: string;                        // display name for breadcrumbs
  exact?: boolean;                      // default: true
}): void
```

Map a URL path to a React component. Works with React Router — `path` supports named parameters like `/resources/:namespace/:name`.

```typescript
registerRoute({
  path:      '/observability/traces/:traceId',
  sidebar:   'observability',
  component: ({ match }) => <TraceDetail id={match.params.traceId} />,
});
```

---

## registerDetailsViewSection

```typescript
registerDetailsViewSection(config: {
  resource: KubeObjectClass;           // e.g. K8s.ResourceClasses.Pod
  section: (item: any) => React.ReactElement | null;
}): void
```

Append a custom section to any Kubernetes resource detail view. The `section` function receives the full resource object and returns a React element (or null to skip rendering for that instance).

```typescript
import { registerDetailsViewSection } from '@kinvolk/headlamp-plugin/lib';
import { K8s } from '@kinvolk/headlamp-plugin/lib';

registerDetailsViewSection({
  resource: K8s.ResourceClasses.Pod,
  section: (pod) => {
    const spiffeId = pod.metadata?.annotations?.['spiffe.io/spiffe-id'];
    if (!spiffeId) return null;
    return (
      <SectionBox title="SPIFFE Identity">
        <code>{spiffeId}</code>
      </SectionBox>
    );
  },
});
```

---

## registerDetailsViewHeaderAction

```typescript
registerDetailsViewHeaderAction(config: {
  resource: KubeObjectClass;
  action: (item: any) => React.ReactElement | null;
}): void
```

Add action buttons to the header of resource detail views, alongside the built-in Edit and Delete buttons.

```typescript
registerDetailsViewHeaderAction({
  resource: K8s.ResourceClasses.Deployment,
  action: (deploy) => (
    <Button onClick={() => triggerRollout(deploy)}>
      Force Rollout
    </Button>
  ),
});
```

---

## registerResourceTableColumnsProcessor

```typescript
registerResourceTableColumnsProcessor(
  processor: (args: {
    id: string;
    columns: Column[];
  }) => Column[]
): void
```

Intercept and modify the column list for any resource table. Return the modified columns array. You can add, remove, or reorder columns.

```typescript
registerResourceTableColumnsProcessor(({ id, columns }) => {
  if (id !== 'pods') return columns;

  return [
    ...columns,
    {
      id: 'spiffe-id',
      label: 'SPIFFE ID',
      getValue: (pod) =>
        pod.metadata?.annotations?.['spiffe.io/spiffe-id'] ?? '—',
    },
  ];
});
```

---

## registerClusterChooserButton

```typescript
registerClusterChooserButton(
  component: React.ComponentType<{ onClick: () => void }>
): void
```

Replace the default cluster chooser button with a custom one. Receives an `onClick` prop that opens the built-in cluster switcher.

---

## registerAppLogo

```typescript
registerAppLogo(
  component: React.ComponentType<{ className?: string }>
): void
```

Replace the Headlamp logo with your own SVG or image component. Used for white-label deployments.

```typescript
import { registerAppLogo } from '@kinvolk/headlamp-plugin/lib';

function MyLogo({ className }: { className?: string }) {
  return <img src="/plugins/my-plugin/logo.svg" className={className} alt="My Platform" />;
}

registerAppLogo(MyLogo);
```

---

## registerPluginSettings

```typescript
registerPluginSettings(config: {
  name: string;
  component: React.ComponentType<{
    data: Record<string, any>;
    onDataChange: (data: Record<string, any>) => void;
  }>;
  displayName?: string;
  description?: string;
}): void
```

Expose a settings panel for your plugin at **Settings → Plugins → {your-plugin}**. Users can configure your plugin without redeployment. Settings are persisted in localStorage.

```typescript
registerPluginSettings({
  name: 'my-plugin',
  displayName: 'My Plugin Settings',
  component: ({ data, onDataChange }) => (
    <TextField
      label="Repo URL"
      value={data.repoUrl ?? ''}
      onChange={(e) => onDataChange({ ...data, repoUrl: e.target.value })}
    />
  ),
});
```

---

## registerSidebarEntryFilter

```typescript
registerSidebarEntryFilter(
  filter: (entry: SidebarEntry) => SidebarEntry | null
): void
```

Show or hide sidebar entries conditionally. Return the entry to show it, or `null` to hide. Useful for feature flags, RBAC-based hiding, or environment-conditional navigation.

```typescript
registerSidebarEntryFilter((entry) => {
  // hide the SPIFFE section if not on a SPIRE-enabled cluster
  if (entry.name === 'spiffe' && !clusterHasSpire()) return null;
  return entry;
});
```

---

## Using settings in your components

Settings registered via `registerPluginSettings` can be read anywhere in your plugin:

```typescript
import { getHeadlampAPIHeaders } from '@kinvolk/headlamp-plugin/lib';

// read persisted settings
const settings = JSON.parse(
  localStorage.getItem('headlamp-plugin-settings-my-plugin') ?? '{}'
);
const repoUrl = settings.repoUrl ?? '/serviceproxy/default/my-repo/';
```
