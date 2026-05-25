# Greediness Deep Dive

Understanding greediness means understanding how the NFA engine explores the search tree.

---

## How Greedy Matching Works

A greedy quantifier first tries to consume the **maximum** possible characters. If the rest of the pattern fails, it gives back one character (backtracks) and tries again, repeating until the overall match succeeds or all possibilities are exhausted.

```
Pattern: /a.*b/
String:  "aXbXb"

Step 1: .* consumes entire string → "aXbXb"
Step 2: Try to match 'b' — at end of string, fail
Step 3: Backtrack — .* gives back 'b' → at position "aXbX"
Step 4: Try to match 'b' at 'b' — success!
Result: "aXbXb" (the whole string — greedy took last b)
```

---

## How Lazy Matching Works

A lazy quantifier first tries to consume the **minimum**. If the rest of the pattern fails, it expands by one character and retries.

```
Pattern: /a.*?b/
String:  "aXbXb"

Step 1: .*? consumes nothing → try 'b' at 'X' — fail
Step 2: .*? expands to 'X' → try 'b' at 'b' — success!
Result: "aXb" (shortest match)
```

---

## Visualizing the Difference

| Pattern | Input | Result |
|---------|-------|--------|
| `".*"` (greedy) | `"start" middle "end"` | `"start" middle "end"` |
| `".*?"` (lazy) | `"start" middle "end"` | `"start"` (first match) |
| `"[^"]*"` (class) | `"start" middle "end"` | `"start"` (first match, fastest) |

---

## Lazy ≠ Faster

!!! info "Common Misconception"
    Lazy quantifiers are often assumed to be faster because they match less. They're not.  
    Both greedy and lazy do backtracking. The difference is which **direction** they explore.  
    For guaranteed performance, use possessive quantifiers or atomic groups.

---

## The Backtracking Problem Illustrated

```
Pattern: ^(a+)*b
Input:   "aaaaaaaaaaaX"   (no 'b' at end)

The engine must try ALL ways to partition "aaaa...a" into groups:
  (a)(a)(a)(a)...(a) → fail
  (aa)(a)(a)...(a)   → fail
  (aaa)...           → fail
  ...2^n combinations total
```

This is catastrophic backtracking. See [Catastrophic Backtracking](../engines/backtracking.md).

---

## Greedy Ordering Rules

1. `*` and `+` consume as much as possible, then give back one at a time
2. `?` tries to match (greedy) before trying to skip
3. Quantifiers apply to the **immediately preceding** atom
4. Parenthesized groups count as one atom for quantifier purposes

```regex
ab*c     # 'b' is quantified, not 'ab'
(ab)*c   # 'ab' is quantified
```
