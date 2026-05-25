# Quantifiers

Quantifiers specify **how many times** the preceding token or group must appear.

---

## Quantifier Reference

| Quantifier | Meaning | Mode |
|------------|---------|------|
| `*` | 0 or more | Greedy |
| `+` | 1 or more | Greedy |
| `?` | 0 or 1 | Greedy |
| `{n}` | Exactly n times | Greedy |
| `{n,}` | n or more | Greedy |
| `{n,m}` | Between n and m | Greedy |
| `*?` | 0 or more | Lazy (minimal) |
| `+?` | 1 or more | Lazy (minimal) |
| `??` | 0 or 1 | Lazy (prefer skip) |
| `{n,m}?` | n to m | Lazy (minimal) |
| `*+` | 0 or more | Possessive (no backtrack) |
| `++` | 1 or more | Possessive (no backtrack) |
| `?+` | 0 or 1 | Possessive (no backtrack) |

---

## Greedy, Lazy, and Possessive Compared

```
String:  "start" middle "end"
```

| Mode | Pattern | Result | Explanation |
|------|---------|--------|-------------|
| Greedy | `".*"` | `"start" middle "end"` | Consumes max, one big match |
| Lazy | `".*?"` | `"start"` then `"end"` | Two smallest matches |
| Preferred | `"[^"]*"` | `"start"` then `"end"` | Faster, no backtrack risk |

!!! tip "Best Practice"
    Prefer negated character classes (`[^"]*`, `[^>]*`) over lazy quantifiers (`.*?`) wherever the delimiter is a single known character.  
    They are faster, clearer, and **cannot** catastrophically backtrack.

---

## Quantifier on Groups vs. Characters

```regex
\d{4}            # exactly 4 digits
(?:ab){3}         # "ababab"
(?:red|blue){2}   # "redred", "redblue", "bluered", "blueblue"
-?                # optional leading minus
\d+\.?\d*      # simple decimal: 42, 3.14, 100.
```

---

## Lazy ≠ Faster

!!! info "Common Misconception"
    Lazy quantifiers are often assumed to be faster. They're not — they just find a **different (smaller)** match.  
    Both greedy and lazy do backtracking. The difference is which *direction* they explore the search tree.  
    **Possessive quantifiers and atomic groups are the true performance win.**

---

## `{n,m}` Syntax Gotchas

```regex
{3}      # exactly 3 — most engines
{3,}     # 3 or more
{3,6}    # 3 to 6 — NO space around comma (some engines reject it)
{0,1}    # equivalent to ?
{1,}     # equivalent to +
{0,}     # equivalent to *

# In some engines, a {n} that looks like it can't be a quantifier
# is treated as a literal: "a{b}" might match literally "a{b}"
# Safest: always escape { } when you mean them literally
```

---

## Possessive Quantifiers (PCRE / Java / Ruby)

Possessive quantifiers match as much as possible and **never give characters back**, even if the overall match fails. This eliminates the backtracking paths that cause exponential blowup.

```regex
\d++        # match digits possessively
(?:ab)++    # possessive on a group
[a-z]++[a-z]  # will always fail if input is all-alpha — no backtrack
```

See [Atomic Groups & Possessive](../advanced/atomic-groups.md) and [Catastrophic Backtracking](../engines/backtracking.md) for why this matters.
