# Catastrophic Backtracking

Catastrophic backtracking (sometimes called "exponential backtracking") occurs when a regex can attempt an exponential number of paths through a string. It's the defining performance vulnerability of NFA engines.

---

## The Classic Trap: Nested Quantifiers

```
Pattern: (a+)+  against "aaaa...X" (no 'b' at end)
For n=20 'a's → ~2^20 = 1,048,576 paths
For n=30 → over 1 billion paths → seconds or minutes of CPU time
```

Path explosion for `(a+)+` on `"aaaa"` (4 chars, no match):

```
(a)(a)(a)(a)  → fail
(a)(a)(aa)    → fail
(a)(aa)(a)    → fail
(a)(aaa)      → fail
(aa)(a)(a)    → fail
(aa)(aa)      → fail
(aaa)(a)      → fail
(aaaa)        → fail
= 8 paths for 4 chars, 2^n in general
```

---

## Identifying Vulnerable Patterns

A pattern is potentially catastrophic if:

1. **Nested quantifiers:** `(a+)+`, `(a*)*`, `(a|a)+`
2. **Overlapping alternatives with quantifiers:** `(\w|\w)+`
3. **Two adjacent quantified groups can match the same characters:** `\w+\d+` on all-alpha input

### Diagnostic Question

> "If the match fails at the very last character, how many ways can the engine partition everything before that character?"

If the answer grows exponentially with input length, the pattern is vulnerable.

---

## Real-World Catastrophic Patterns

```regex
# Email — vulnerable
(([a-zA-Z0-9])+\.?)+@    # nested quantifiers

# Safer
[a-zA-Z0-9](?:[a-zA-Z0-9.]*[a-zA-Z0-9])?@

# HTTP header parsing — vulnerable
(\S+\s*)+:              # catastrophic on long non-matching lines

# Safer
\S[^:]*:
```

---

## The Cloudflare Outage (2019)

On July 2, 2019, Cloudflare's WAF deployed a new rule containing a regex with catastrophic backtracking. It caused 100% CPU usage on all WAF processes globally, taking down Cloudflare's HTTP/HTTPS services for ~27 minutes.

The vulnerable sub-pattern:

```
(?:(?:\"|'|\]|\}|\\|\d|(?:nan|infinity|true|false|null|undefined|symbol|math)|`|\-|\+)+[)]*;?((?:\s|-|~|!|\{\}|\|\||\+)*.*)
```

The trailing `.*` combined with the repetition of the outer group created exponential backtracking on certain inputs. The fix was pattern restructuring.

---

## Fixes

### 1. Flatten Nested Quantifiers

```regex
# Vulnerable
(a+)+

# Fixed — if the outer repetition is unnecessary, remove it
a+
```

### 2. Make Alternatives Non-Overlapping

```regex
# Vulnerable — \w and \w are identical; exponential partitioning
(\w|\w)+

# Fixed
\w+
```

### 3. Use Possessive Quantifiers or Atomic Groups

```regex
# PCRE/Java — possessive
a++b

# PCRE/Java — atomic group
(?>a+)+b
```

### 4. Switch to a Linear-Time Engine

Use Go's `regexp`, Rust's `regex` crate, or embed Google RE2 via a library binding. These **cannot** catastrophically backtrack — they're O(n) by design.

---

## Testing for Vulnerability

Tools:

- **[vuln-regex-detector](https://github.com/nicowillis/vuln-regex-detector)** — static analysis
- **[RXXR2](https://github.com/nicowillis/rxxr2)** — regex vulnerability analysis
- **[regex101.com](https://regex101.com)** — shows step count in debugger
- **safe-regex** (npm) — JavaScript package for static detection

Manual test: apply your pattern to a string of `n` repeated characters that **won't match**, then measure time as `n` grows. Linear time is safe; superlinear time indicates vulnerability.
