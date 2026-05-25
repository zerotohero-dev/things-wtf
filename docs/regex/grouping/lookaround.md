# Lookahead & Lookbehind

Lookaround assertions check for a pattern **without consuming characters**. They are zero-width — the engine's position doesn't advance regardless of whether the assertion passes or fails.

---

## Types

| Syntax | Name | Matches when… |
|--------|------|----------------|
| `(?=foo)` | Positive lookahead | Current position is followed by `foo` |
| `(?!foo)` | Negative lookahead | Current position is **not** followed by `foo` |
| `(?<=foo)` | Positive lookbehind | Current position is preceded by `foo` |
| `(?<!foo)` | Negative lookbehind | Current position is **not** preceded by `foo` |

---

## Lookahead Examples

```regex
# Number followed by " dollars" — don't capture " dollars"
\d+(?= dollars)
# Input: "100 dollars and 200 euros"
# Matches: "100"  (not "200" — " dollars" doesn't follow it)

# Password validation — require digit, uppercase, special char
^(?=.*\d)(?=.*[A-Z])(?=.*[!@#$%]).{8,}$
# All three lookaheads must pass from position 0

# Don't match foo when it's followed by "bar"
foo(?!bar)    # matches "foo" in "fooXXX" but not in "foobar"
```

---

## Lookbehind Examples

```regex
# Extract value after a key
(?<=version:\s)\S+    # "1.2.3" in "version: 1.2.3"

# Don't match "foo" when preceded by "no "
(?<!no )foo    # matches "there is foo" but not "there is no foo"

# Add thousands separator (insert comma at every thousand boundary)
(?<=\d)(?=(\d{3})+(?!\d))    # replace with ","
```

---

## Chaining Lookaheads

Multiple lookaheads can be stacked at the same position:

```regex
^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z\d]).{12,}$
# Password: uppercase + lowercase + digit + special, min 12 chars
```

Each `(?=…)` scans forward from position `^` independently. All must succeed.

---

## Variable-Length Lookbehind

Most engines require lookbehind patterns to be **fixed-length**:

```regex
# ✗ Fails in most engines (variable-length lookbehind)
(?<=\w+:)\d+

# ✓ .NET and Python 3.x allow variable-length lookbehind
# ✓ Use \K in PCRE as an alternative
\w+:\K\d+    # \K resets match start; everything before is discarded
```

| Engine | Variable-length lookbehind |
|--------|--------------------------|
| Python 3.x | ✓ (since 3.7) |
| .NET | ✓ |
| PCRE2 | Limited / use `\K` |
| Java | ✗ (fixed only) |
| JavaScript | ✗ (fixed only; ES2018 added lookbehind at all) |
| Go (RE2) | ✗ (no lookbehind at all) |

---

## `\K` — Match Reset (PCRE)

`\K` is a PCRE extension that discards everything matched so far, effectively acting as a lookbehind without the length restriction:

```regex
version:\s*\K[\d.]+
# Matches only the version number, not "version: " prefix
```

---

## Performance Note

Lookaheads re-scan forward from the current position. Multiple lookaheads, or lookaheads containing `.*`, multiply the work. For performance-sensitive paths:

```regex
# Slow — each lookahead does an O(n) scan
^(?=.*foo)(?=.*bar)(?=.*baz).+$

# Faster — find them in order if ordering is acceptable
foo.*bar.*baz
```
