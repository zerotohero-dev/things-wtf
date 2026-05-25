# Bash Reference

A comprehensive Bash reference covering everything from boilerplate to 3am triage.
Built for engineers who need fast lookup during on-call, not a tutorial.

---

## Sections

### Fundamentals

| # | Section | What's inside |
|---|---------|---------------|
| 01 | [Setup & Safety](setup-safety.md) | `set -euo pipefail`, canonical headers, cleanup traps |
| 02 | [Variables](variables.md) | Declaration, scope, `declare` flags, special vars |
| 03 | [Strings & Quoting](strings-quoting.md) | Quoting rules, string ops, case conversion, trim |
| 04 | [Arrays](arrays.md) | Indexed arrays, associative arrays, `mapfile` |
| 05 | [Arithmetic](arithmetic.md) | `$(( ))`, `(( ))`, float via `bc`/`awk`, gotchas |
| 06 | [Conditionals](conditionals.md) | `if/elif/else`, `[[ ]]` vs `[ ]`, test operators |
| 07 | [Loops](loops.md) | `for`, C-style, `while`, `until`, `read` line-by-line |
| 08 | [Functions](functions.md) | `local`, return via stdout, namerefs, recursion |
| 09 | [case / select](case-select.md) | Pattern matching, fallthrough, `getopts` |

### I/O & Processes

| # | Section | What's inside |
|---|---------|---------------|
| 10 | [I/O & Redirection](io-redirection.md) | FDs, heredoc, herestring, `tee`, redirect order |
| 11 | [Pipes, tee, xargs](pipes-tee-xargs.md) | `PIPESTATUS`, named pipes, `xargs -0`, parallel |
| 12 | [Process Substitution](process-substitution.md) | `<()` and `>()`, variable scope fix |
| 13 | [Forking & Background Jobs](forking-background.md) | `&`, `wait`, job control, `disown`, `nohup` |
| 14 | [Subshells vs Command Groups](subshells.md) | `( )` vs `{ }`, pipeline variable scope trap |

### Robustness

| # | Section | What's inside |
|---|---------|---------------|
| 15 | [Traps & Signals](traps-signals.md) | `EXIT`/`ERR`/`INT`/`TERM`, quoting in traps |
| 16 | [Error Handling Patterns](error-handling.md) | `die`/`warn`/`info`, `require_cmd`, `retry` with backoff |
| 17 | [Debugging](debugging.md) | `bash -n/-x/-v`, `PS4`, `declare -p`, shellcheck |

### Quick Reference

| # | Section | What's inside |
|---|---------|---------------|
| 18 | [Quirks & Pitfalls](quirks-pitfalls.md) | 0=success, word splitting, `set -e` edge cases, IFS |
| 19 | [Parameter Expansion](parameter-expansion.md) | Full `${var...}` cheatsheet including `@Q`/`@A`/`@a` |
| 20 | [Special Variables](special-variables.md) | `$@`, `$?`, `$$`, `$!`, `$PIPESTATUS`, all of them |
| 21 | [Test Operators](test-operators.md) | File tests, string tests, integer tests |

### Recipes

| # | Section | What's inside |
|---|---------|---------------|
| 22 | [Mini Scripts](mini-scripts.md) | Lockfile, retry, logging, spinner, semaphore, config parser, backup rotation |
| 23 | [One-liners](one-liners.md) | ~25 high-value one-liners for files, processes, network, k8s |
| 24 | [3am Triage](triage.md) | System state, Kubernetes triage, disk full, network debugging |

---

!!! tip "Quick tip"
    Use your browser's built-in search (or the search bar above) to jump straight to what you need.
    The [Quirks & Pitfalls](quirks-pitfalls.md) and [3am Triage](triage.md) sections are the most
    useful when things are already on fire.
