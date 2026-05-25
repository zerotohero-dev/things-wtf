# Performance

---

## Complexity by Pattern Type

| Pattern Type | Complexity | Notes |
|---|---|---|
| Simple literal | O(n) | Optimized to Boyer-Moore or similar |
| Character class | O(n) | Lookup table in engine |
| Simple alternation | O(n) | Each alternative tried linearly |
| Greedy `.*` | O(n²) typical | Backtracking on complex suffixes |
| Nested quantifiers `(a+)+` | O(2^n) worst | Catastrophic — avoid |
| Backreferences | NP-hard in general | Use sparingly; bound your groups |
| Lookahead (simple) | O(n) per lookahead | Multiple lookaheads multiply |

---

## Optimization Tips

### 1. Compile and Cache Patterns

```js
// BAD — recompiles on every call
function isEmail(s) { return /^[^@]+@[^@]+$/.test(s); }

// GOOD — compiled once at module load
const EMAIL_RE = /^[^@]+@[^@]+$/;
function isEmail(s) { return EMAIL_RE.test(s); }
```

```java
// Java — always use static final for patterns
private static final Pattern DATE_RE =
    Pattern.compile("(\\d{4})-(\\d{2})-(\\d{2})");
```

### 2. Anchor When You Can

`^` and `\A` tell the engine to try only from position 0, avoiding a full scan:

```regex
^\d+$      # fast — only tries from start
\d+$       # slower — tries at every position
```

### 3. Use Specific Character Classes

```regex
[0-9]      # over .  — reduces match space
[^,]*      # over .* — negated class, no backtracking
[^"]*      # over .*? — same result, much faster
```

### 4. Prefer Negated Classes over Lazy Quantifiers

```regex
# Slow (lazy, can backtrack)
".*?"

# Fast (negated class, linear, cannot backtrack)
"[^"]*"
```

### 5. Avoid Unnecessary Captures

```regex
(foo|bar)      # allocates a capture buffer
(?:foo|bar)    # no allocation — use this when capture isn't needed
```

### 6. Put Common Alternatives First (NFA engines)

```regex
(?:jpg|jpeg|png|gif|webp)    # if jpeg is rare, put jpg first
```

### 7. Use Possessive Quantifiers or Atomic Groups

Cut off backtracking paths early when you know the match is unambiguous.  
See [Atomic Groups & Possessive](../advanced/atomic-groups.md).

### 8. Validate Input Length First

```js
if (input.length > 1000) throw new Error("input too long");
// Then apply regex
```

### 9. Benchmark with Representative Data

Don't optimize blind. Use:

- `console.time()` / `time.perf_counter()` with real-world samples
- regex101.com's debugger to visualize backtracking steps
- The `regex` module's `timeout` parameter (Python)

---

## Profiling Backtracking

regex101.com shows the number of regex engine steps. A well-written pattern on a 100-char string should take tens of steps, not thousands.

| Steps | Assessment |
|-------|------------|
| < 100 | Excellent |
| 100–1000 | Acceptable for trusted input |
| 1000–10000 | Warning — consider restructuring |
| > 10000 | Danger — vulnerable to ReDoS on longer input |
