# Decisions

<!-- INDEX:START -->
| Date | Decision |
|------|--------|
| 2026-03-31 | Dual-site separation for public and internal docs |
<!-- INDEX:END -->

<!-- DECISION FORMATS

## Quick Format (Y-Statement)

For lightweight decisions, a single statement suffices:

> "In the context of [situation], facing [constraint], we decided for [choice]
> and against [alternatives], to achieve [benefit], accepting that [trade-off]."

## Full Format

For significant decisions:

## [YYYY-MM-DD] Decision Title

**Status**: Accepted | Superseded | Deprecated

**Context**: What situation prompted this decision? What constraints exist?

**Alternatives Considered**:
- Option A: [Pros] / [Cons]
- Option B: [Pros] / [Cons]

**Decision**: What was decided?

**Rationale**: Why this choice over the alternatives?

**Consequence**: What are the implications? (Include both positive and negative)

**Related**: See also [other decision] | Supersedes [old decision]

## When to Record a Decision

✓ Trade-offs between alternatives
✓ Non-obvious design choices
✓ Choices that affect architecture
✓ "Why" that needs preservation

✗ Minor implementation details
✗ Routine maintenance
✗ Configuration changes
✗ No real alternatives existed

-->
## [2026-03-31-081949] Dual-site separation for public and internal docs

**Status**: Accepted

**Context**: Need both public (Cloudflare Pages) and internal (local-only) documentation, facing the risk of accidental publication of internal content

**Decision**: Dual-site separation for public and internal docs

**Rationale**: Two independent Zensical sites with separate source dirs (docs/, docs-internal/), configs (zensical.toml, zensical-internal.toml), and output dirs (site/, site-internal/) — chosen over a single site with filtered output or nav-level separation — to achieve hard isolation where internal content is never even input to the public build

**Consequence**: Maintaining two config files. Internal source and output are gitignored. Safe by default: running zensical build with no flags always produces the public site only. Spec: specs/dual-site-separation.md
