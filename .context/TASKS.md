# Tasks

<!--
UPDATE WHEN:
- New work is identified → add task with #added timestamp
- Starting work → add #in-progress or #started timestamp
- Work completes → mark [x] with #done timestamp
- Work is blocked → add to Blocked section with reason
- Scope changes → update task description inline

DO NOT UPDATE FOR:
- Reorganizing or moving tasks (violates CONSTITUTION)
- Removing completed tasks (use ctx task archive instead)

STRUCTURE RULES (see CONSTITUTION.md):
- Tasks stay in their Phase section permanently: never move them
- Use inline labels: #in-progress, #blocked, #priority:high
- Mark completed: [x], skipped: [-] (with reason)
- Never delete tasks, never remove Phase headers

TASK STATUS LABELS:
  `[ ]`: pending
  `[x]`: completed
  `[-]`: skipped (with reason)
  `#in-progress`: currently being worked on (add inline, don't move task)
-->

### Phase 1: Dual-Site Separation `#priority:high`
Spec: `specs/dual-site-separation.md`

- [x] Read `specs/dual-site-separation.md` before starting any P1 task #added:2026-03-30-214500 #done:2026-03-30-215000
- [x] Add `site-internal/` and `docs-internal/` to `.gitignore` #added:2026-03-30-214500 #done:2026-03-30-215000
- [x] Move `docs/internal/*` → `docs-internal/`, create `docs-internal/index.md` #added:2026-03-30-214500 #done:2026-03-30-215100
- [x] Remove empty `docs/internal/` directory #added:2026-03-30-214500 #done:2026-03-30-215100
- [x] Create `zensical-internal.toml` (docs_dir, site_dir, distinct identity) #added:2026-03-30-214500 #done:2026-03-30-215200
- [x] Add Makefile targets: `serve`, `serve-internal`, `build`, `build-internal` #added:2026-03-30-214500 #done:2026-03-30-215200
- [x] Verify: `zensical build` produces `site/` with no internal content #added:2026-03-30-214500 #done:2026-03-30-215300
- [x] Verify: `zensical build -f zensical-internal.toml` produces `site-internal/` #added:2026-03-30-214500 #done:2026-03-30-215300
- [x] Verify: `git status` shows no `docs-internal/` or `site-internal/` files #added:2026-03-30-214500 #done:2026-03-30-215300

## Blocked
