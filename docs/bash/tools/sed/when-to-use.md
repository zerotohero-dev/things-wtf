# When to Use Which

A quick decision table for picking the right tool before you start typing.

---

## Decision Table

| Task | Best Tool | Why |
|------|-----------|-----|
| Replace a string in a file | **sed** | `s/old/new/` is exactly its job |
| Delete lines matching a pattern | **sed** | `/pattern/d` is direct and fast |
| Insert a line before/after a match | **sed** | `i\` and `a\` commands |
| Extract a specific column from CSV/TSV | **awk** | `$N` field splitting is native |
| Sum / count values from a log | **awk** | Has variables and arithmetic |
| Multiple transformations per line | **awk** | Full control flow; sed gets unwieldy |
| Reformat / print with custom layout | **awk** | `printf` gives full format control |
| Interactively select a file to edit | **fzf** | Real-time fuzzy filter over any list |
| Search command history | **fzf** | Shell integration replaces Ctrl-R |
| Pick a git branch to checkout | **fzf** | Can preview commit graph per selection |
| Complex multi-file transformations | Python/Perl | Reach for a real language at this point |

---

## When sed Gets Awkward

Reach for `awk` instead of `sed` when you need:

- Arithmetic (sed has none)
- More than one field from a line (sed has no field concept)
- Counters or aggregations across lines
- Arrays or associative data structures
- Multiple conditions with different actions per condition

---

## When awk Gets Awkward

Reach for `sed` instead of `awk` when:

- You just need a simple substitution — `sed 's/a/b/'` beats an `awk` program for legibility
- You need to edit a file in-place with a backup (`sed -i.bak`)
- You're doing hold-space tricks like reversing line order or inserting a line relative to another

---

## When to Add fzf

Add `fzf` to any pipeline when a **human needs to make a choice** from a list. If the selection can be determined programmatically, skip it. If you'd otherwise have to print a numbered list and prompt for input, replace that entire UX with `fzf`.

---

## The Composition Sweet Spot

```bash
# awk extracts → sed cleans → fzf selects → awk extracts → command acts
kubectl get pods -A -o wide \
  | awk 'NR>1 {print $1, $2, $4}' \
  | sed 's/Running/✓/' \
  | fzf --header "NAMESPACE POD STATUS" \
  | awk '{print $1, $2}' \
  | xargs -n2 kubectl logs -f -n
```
