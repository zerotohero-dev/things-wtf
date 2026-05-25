# Backreferences

Backreferences (`\1`, `\2`, … or `\k<name>`) refer to the **text captured** by a previous group — not the pattern itself. This is what pushes regex beyond true regular languages.

---

## Basic Backreferences

```regex
# Match doubled words
\b(\w+)\s+\1\b    # \1 must equal whatever \w+ captured

# Match HTML-like paired tags (brittle — use a parser for real HTML!)
<(\w+)>[^<]*<\/\1>    # <b>text</b>, <div>text</div>

# Match quoted strings with consistent quoting
(['"])(?:(?!\1).)*\1    # 'hello' or "hello" — not mismatched 'hello"
```

!!! warning "Performance Warning"
    Backreferences force NFA engines into potentially exponential time.  
    A pattern like `(.+)\1` applied to a long string with no match can be catastrophically slow.  
    Always bound your groups and be cautious with backreferences on untrusted input.

---

## Named Backreferences

```regex
# JS
/\b(?<word>\w+)\s+\k<word>\b/gi

# Python
r'\b(?P<word>\w+)\s+(?P=word)\b'

# PCRE/Java
(?<word>\w+)\s+\k<word>
```

---

## Backreferences in Replacements

```js
// JS — swap first and last name
"Smith, John".replace(/^(\w+),\s*(\w+)$/, '$2 $1')
// → "John Smith"

// Named groups in replacement
"2024-07-04".replace(/(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})/, '$<d>/$<m>/$<y>')
// → "04/07/2024"
```

```python
# Python
re.sub(r'^(\w+),\s*(\w+)$', r'\2 \1', "Smith, John")
# → 'John Smith'
```

```java
// Java
"Smith, John".replaceAll("^(\\w+),\\s*(\\w+)$", "$2 $1")
// → "John Smith"
```

---

## What Backreferences Are Not

A backreference matches the **captured text**, not the **pattern** again.

```regex
(\d+)\s+\1
```

Applied to `"123 123"` — matches (both groups captured "123").  
Applied to `"123 456"` — **no match** (\1 is "123", but next token is "456").

This is fundamentally different from:

```regex
\d+\s+\d+    # matches any two numbers — no equality constraint
```

---

## Engine Support

| Feature | JS | Python | Go | Java | PCRE |
|---------|----|--------|----|------|------|
| `\1` numeric | ✓ | ✓ | ✗ | ✓ | ✓ |
| `\k<name>` | ✓ | ✗ | ✗ | ✓ | ✓ |
| `(?P=name)` | ✗ | ✓ | ✗ | ✗ | ✗ |

Go's RE2 does not support backreferences at all — use post-processing in Go code instead.
