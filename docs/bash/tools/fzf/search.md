# fzf — Search Syntax

fzf uses its own extended search syntax (enabled by default with `--extended`, which is on by default). Multiple terms are separated by spaces and act as **AND**.

---

## Token Types

| Token | Match Type | Description |
|-------|-----------|-------------|
| `sbtrkt` | fuzzy | Items that fuzzy-match "sbtrkt" (any chars between) |
| `'word` | exact | Items that include "word" as an exact substring |
| `^prefix` | prefix-exact | Items that start with "prefix" |
| `suffix$` | suffix-exact | Items that end with "suffix" |
| `!word` | inverse-exact | Items that do **NOT** include "word" |
| `!^prefix` | inverse-prefix | Items that do **NOT** start with "prefix" |
| `!suffix$` | inverse-suffix | Items that do **NOT** end with "suffix" |
| `term1 term2` | AND | Items matching **both** terms (space = AND) |
| `term1 \| term2` | OR | Items matching **either** term (pipe = OR) |

---

## Examples

```bash
# Fuzzy: type partial characters in any order
fzf   # type: cfg   → matches "config", "cfg.yaml", etc.

# Exact: must contain the literal string
fzf   # type: 'test  → matches lines with "test" exactly

# Prefix: must start with "main"
fzf   # type: ^main

# Suffix: must end with ".go"
fzf   # type: .go$

# Inverse: exclude lines containing "vendor"
fzf   # type: !vendor

# AND: .go files that are NOT test files
fzf   # type: .go$ !_test

# AND: files starting with "cmd" and containing "main"
fzf   # type: ^cmd 'main

# OR: files ending in .go OR .sh
fzf   # type: .go$ | .sh$

# Complex: go files, not vendor, not test
fzf   # type: .go$ !vendor !_test
```

---

## Case Sensitivity

By default, fzf is **smart-case**: lowercase query = case-insensitive, uppercase query = case-sensitive.

```bash
# Force case-insensitive
fzf -i
fzf --ignore-case

# Force case-sensitive
fzf +i
fzf --no-ignore-case
```

---

## Disabling Extended Search

```bash
# Pure fuzzy mode only (no exact/prefix/suffix/inverse tokens)
fzf +x
fzf --no-extended

# Force all searches to be exact
fzf --exact
```

---

## Scoping Search with --nth

By default fzf searches the whole line. Use `--nth` to restrict matching to specific fields.

```bash
# Search only on the filename (last slash-delimited field)
find . -type f | fzf --delimiter=/ --nth=-1

# Search only on fields 2 and 3 (tab-delimited)
cat data.tsv | fzf --delimiter='\t' --nth=2,3

# Display only field 2 but search the whole line
cat data.txt | fzf --with-nth=2
```

---

## Scoring

fzf scores matches using an algorithm that prefers:

1. **Consecutive** matching characters over scattered ones
2. Characters at **word boundaries** (after `/`, `_`, `-`, `.`, space)
3. Characters at the **start** of the string
4. **Shorter** strings (fewer total characters)

This means typing a partial filename like `mkd` will score `mkdocs.yml` higher than a long path that happens to contain those letters scattered throughout.

```bash
# Use the v1 algorithm (faster, slightly less accurate)
fzf --algo=v1

# Default: v2 (Smith-Waterman variant)
fzf --algo=v2
```
