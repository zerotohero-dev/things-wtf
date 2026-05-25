# Gotchas & Traps

A curated list of the most common regex mistakes, each with a clear explanation and fix.

---

## 1. `re.match()` is Anchored (Python)

```python
re.match(r'\d+', 'abc 123')   # None — no digits at START
re.search(r'\d+', 'abc 123')  # matches '123' — scans forward
```

`re.match()` only matches at the beginning of the string. It's effectively `^pattern`. Use `re.search()` for scan behavior.

---

## 2. Alternation Short-Circuits Left-to-Right (NFA)

```regex
# 'https|http' — "https" is never matched
http://...    matches "http"
https://...   matches "http" ← BUG — stops at first alternative

# Fix: longer alternative first, or use ?
https?://     # ✓
https|http    # ✗
```

---

## 3. `$` Allows a Trailing Newline

```python
re.match(r'^\d+$', '123\n')    # matches! $ is lenient
re.match(r'^\d+\Z', '123\n')  # None — \Z is strict
```

Use `\Z` (Python/PCRE) or `\z` (Ruby/Java) for strict string termination.

---

## 4. Hyphen Position in Character Classes

```regex
[a-z0-9-]    # ✓ — hyphen at end (literal)
[-a-z0-9]    # ✓ — hyphen at start (literal)
[a-z\-0-9]  # ✓ — escaped
[a-z0-9_-]   # ⚠ may be interpreted as '_' through '-' range in some engines
```

When in doubt: put the hyphen **first or last**, or escape it.

---

## 5. `^` Inside Character Classes

```regex
[^abc]    # negation — NOT a, b, or c (^ is first)
[a^bc]    # literal ^ in the middle (not negation)
[abc^]    # literal ^ at end
```

`^` only negates when it's the **first character** inside `[…]`.

---

## 6. Dot Doesn't Match Newline by Default

```js
// . does NOT match \n without the s flag
/start.*end/.test("start\nend")     // false
/start.*end/s.test("start\nend")    // true  (ES2018+ /s flag)
/start[\s\S]*end/.test("start\nend")  // true  (older workaround)
```

---

## 7. `match()` with `/g` Drops Group Captures (JS)

```js
"12x 34y".match(/(\d+)(\w)/g)
// ["12x", "34y"] — groups are lost!

// Use matchAll() to preserve groups
[..."12x 34y".matchAll(/(\d+)(\w)/g)]
// [["12x","12","x"], ["34y","34","y"]]
```

---

## 8. `Matcher.matches()` vs `Matcher.find()` (Java)

```java
// matches() — entire string must match
Pattern.matches("\\d+", "123abc")    // false — partial match fails

// find() — scan for pattern anywhere
Pattern p = Pattern.compile("\\d+");
p.matcher("123abc").find()              // true — finds "123"
```

Confusing these is the single most common Java regex bug.

---

## 9. Forgetting Double Backslash in Java/C Strings

```java
// ✗ Wrong — Java sees \d as invalid escape → compile-time warning
Pattern.compile("\d+")

// ✓ Correct — "\\d" in Java string literal = \d in regex
Pattern.compile("\\d+")
```

Python raw strings avoid this entirely: `r'\d+'` is always safe.

---

## 10. Zero-Length Match Behavior

```js
"abc".replace(/(?=.)/g, "X")    // "XaXbXcX" — zero-width positions
```

Replacing zero-length matches inserts the replacement at every position. Engines handle this differently (some skip adjacent zero-length matches, some don't). Test explicitly.

---

## 11. Case-Insensitive and Turkish I

```
Uppercase 'İ' (U+0130, Turkish dotted I) lowercases to 'i'
But lowercase 'i' uppercases to 'İ' in Turkish locale — not 'I'
```

For international text, use Unicode-aware case folding. Avoid assumptions that `i` ↔ `I` is the only case pair.

---

## 12. `\d` Matches Unicode Digits (Python 3, unless `re.A`)

```python
re.findall(r'\d+', '١٢٣')    # ['١٢٣'] — Arabic-Indic digits
re.findall(r'\d+', '١٢٣', re.ASCII)  # [] — ASCII only
```

If you need ASCII digits only in Python 3, use `[0-9]` or the `re.ASCII` flag.

---

## 13. Nested Quantifiers = Catastrophic Backtracking

```regex
(a+)+    # NEVER use this pattern on untrusted input
(\w+)+  # same problem
```

See [Catastrophic Backtracking](../engines/backtracking.md) for full details and fixes.

---

## 14. `lastIndex` Reuse (JS)

```js
const re = /\d+/g;
re.test("123")   // true  — lastIndex = 3
re.test("123")   // false — starts from 3, nothing there, resets to 0
re.test("123")   // true  — starts from 0 again

// Fix: create a fresh regex or reset lastIndex = 0 before each use
```

---

## 15. `split()` with Capturing Groups (JS)

```js
"one1two2".split(/(\d)/)
// ["one", "1", "two", "2", ""] — captured delimiters are included!
```

This is intentional behavior per spec, but often surprises people. Use `(?:\d)` (non-capturing) if you just want the split without capturing delimiters.
