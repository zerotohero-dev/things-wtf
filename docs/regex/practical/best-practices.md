# Best Practices

---

## 1. Compile and Cache Patterns

```js
// ✗ Bad — recompiles on every call
function isEmail(s) { return /^[^@]+@[^@]+$/.test(s); }

// ✓ Good — compiled once at module load
const EMAIL_RE = /^[^@]+@[^@]+$/;
function isEmail(s) { return EMAIL_RE.test(s); }
```

```java
// Java — always declare patterns as static final
private static final Pattern DATE_RE =
    Pattern.compile("(\\d{4})-(\\d{2})-(\\d{2})");
```

---

## 2. Use Verbose Mode for Complex Patterns

```python
SEMVER = re.compile(r'''
  ^
  (?P<major>0|[1-9]\d*)     # major version
  \.
  (?P<minor>0|[1-9]\d*)     # minor version
  \.
  (?P<patch>0|[1-9]\d*)     # patch version
  (?:-(?P<pre>[a-zA-Z0-9.]+))?    # optional pre-release
  (?:\+(?P<build>[a-zA-Z0-9.]+))? # optional build metadata
  $
''', re.VERBOSE)
```

A regex you can read in 6 months is worth more than a compressed one that's 10% faster.

---

## 3. Prefer Non-Capturing Groups

```regex
(?:foo|bar)   # over (foo|bar) unless you need the capture
```

Benefits: faster (no capture buffer), cleaner group numbering, intent is explicit.

---

## 4. Name Your Captures

Named captures make code self-documenting and resilient to refactoring:

```regex
# ✗ Numbered — fragile to structure changes
(\d{4})-(\d{2})-(\d{2})

# ✓ Named — robust and self-documenting  
(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})
```

---

## 5. Validate Input Length Before Applying Regex

```js
if (input.length > 1000) throw new Error("input too long");
// Then apply regex
```

This is especially important for patterns applied to untrusted input.

---

## 6. Don't Use Regex for Structured Data

| Data type | Use instead |
|-----------|-------------|
| HTML/XML | DOM parser, HTMLParser |
| JSON | `JSON.parse()` |
| CSV | Dedicated CSV parser |
| URLs | `URL` constructor, `urllib.parse` |
| Dates | `Date.parse()`, date library |
| Email | Dedicated email validator |

Regex can pre-filter obvious nonsense, but let proper parsers do the heavy lifting.

---

## 7. Test Edge Cases

Always test your patterns against:

- Empty string `""`
- Single character
- All-whitespace string
- Unicode / multibyte characters
- Strings with newlines (check `m` and `s` flag behavior)
- Very long strings (performance)
- Near-miss strings (almost matches but shouldn't)
- Strings with all metacharacters: `. * + ? ^ $ { } [ ] | ( ) \ /`

---

## 8. Comment Your Intent

```js
// ✗ Mystery pattern
const RE = /((?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?)/;

// ✓ Intent is clear
// Validates Base64-encoded strings (RFC 4648)
const BASE64_RE = /((?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?)/;
```

---

## 9. Prefer Character Classes over Alternation for Single Characters

```regex
# ✗ Slow — each option creates NFA states
(a|e|i|o|u)

# ✓ Fast — direct lookup table
[aeiou]
```

---

## 10. Use Anchors Appropriately

```regex
# For full-string validation (email, UUID, etc.) — anchor both ends
^[a-zA-Z0-9]+$

# For extraction — don't anchor unless intent is line-start
\d{4}-\d{2}-\d{2}    # find dates anywhere in text
```

---

## 11. Use `\A` and `\z` for Strict String Boundaries

```regex
# \A = absolute start (not affected by m flag)
# \z = absolute end (no trailing newline allowed)
\A\d+\z    # strictly the entire string is digits
```

In Python, `^` with `re.MULTILINE` matches at every line start — use `\A` when you mean "start of string."

---

## 12. Use Linear-Time Engines for Untrusted Input

When processing input from users, files, or the network:

- Go's `regexp` (RE2)
- Rust's `regex` crate
- Python's `regex` module with `timeout=`
- Java's `re2j` library

See [Security & ReDoS](../engines/security.md).
