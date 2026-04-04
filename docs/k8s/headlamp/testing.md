# Testing

## Backend (Go)

```bash
# run all unit tests
npm run backend:test

# coverage report to stdout
npm run backend:coverage

# coverage report as HTML (opens in browser)
npm run backend:coverage:html
```

Each package has a `*_test.go` file adjacent to the code it tests. The convention is table-driven tests. New packages must include tests — CI enforces coverage thresholds.

### Running a single package

```bash
cd backend
go test ./pkg/helm/...
go test ./pkg/plugins/...
go test -run TestServiceProxy ./pkg/helm/...   # single test by name
```

### Running with verbose output

```bash
cd backend
go test -v ./...
```

## Frontend (TypeScript / React)

```bash
# run all unit tests
npm run frontend:test

# run in watch mode (re-runs on file changes)
cd frontend && npx jest --watch

# run a single test file
cd frontend && npx jest src/components/Button/Button.test.tsx
```

Tests use **Jest** with **React Testing Library**. Test files live next to the component:

```
components/
└── Button/
    ├── index.tsx
    ├── Button.test.tsx    ← Jest unit test
    └── Button.stories.tsx ← Storybook story (also used as visual baseline)
```

### Writing frontend tests

```typescript title="MyComponent.test.tsx"
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import MyComponent from './index';

describe('MyComponent', () => {
  it('renders the expected content', () => {
    render(
      <MemoryRouter>
        <MyComponent title="Test" />
      </MemoryRouter>
    );
    expect(screen.getByText('Test')).toBeInTheDocument();
  });
});
```

## Storybook

Storybook is used for component development, visual review, and as a visual regression baseline.

```bash
npm run frontend:storybook
# opens http://localhost:6006
```

Every new UI component requires a `.stories.tsx` file:

```typescript title="MyComponent.stories.tsx"
import type { Meta, StoryObj } from '@storybook/react';
import MyComponent from './index';

const meta: Meta<typeof MyComponent> = {
  component: MyComponent,
};
export default meta;

type Story = StoryObj<typeof MyComponent>;

export const Default: Story = {
  args: { title: 'Example' },
};
```

## Plugin tests

Plugins use the same Jest toolchain:

```bash
cd my-plugin
npm run test
```

Plugin tests typically:

1. Test utility functions and data transformation logic in isolation
2. Render plugin components with mock Kubernetes resource data
3. Verify that register*() calls don't throw

```typescript title="src/index.test.tsx"
import { render } from '@testing-library/react';
import SpiffeEntryPanel from './SpiffeEntryPanel';

const mockPod = {
  metadata: {
    name: 'my-app',
    annotations: {
      'spiffe.io/spiffe-id': 'spiffe://example.org/ns/default/sa/my-app',
    },
  },
};

it('renders SPIFFE ID from annotations', () => {
  const { getByText } = render(<SpiffeEntryPanel pod={mockPod as any} />);
  expect(getByText('spiffe://example.org/ns/default/sa/my-app')).toBeInTheDocument();
});
```

## OIDC testing

The repo ships a local Dex configuration for testing OIDC flows end-to-end. Required when working on:

- Authentication flows
- The service proxy (which uses the logged-in user's identity)
- Anything that reads OIDC claims or group membership

See `docs/development/oidc.md` in the Headlamp repo for the exact setup steps. The short version is: run the provided `docker-compose.yaml`, configure Headlamp to point at the local Dex instance, and use the test user credentials from the Dex config.

## CI checks

Every PR runs the following automatically:

| Check | Command |
|---|---|
| Backend lint | `npm run backend:lint` |
| Backend tests | `npm run backend:test` |
| Frontend lint | `npm run frontend:lint` |
| Frontend tests | `npm run frontend:test` |
| Frontend build | `npm run frontend:build` |
| Backend build | `npm run backend:build` |
| DCO sign-off | enforced by GitHub Action |

All checks must pass for a PR to be mergeable.
