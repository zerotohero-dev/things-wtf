# Characters & Character Classes

Character classes let you specify a **set** of characters that may appear at a position. They live inside square brackets `[…]`.

---

## Shorthand Classes

| Shorthand | Equivalent | Matches |
|-----------|-----------|---------|
| `\d` | `[0-9]` | Digit |
| `\D` | `[^0-9]` | Non-digit |
| `\w` | `[a-zA-Z0-9_]` | Word char (ASCII) |
| `\W` | `[^a-zA-Z0-9_]` | Non-word char |
| `\s` | `[ \t\n\r\f\v]` | Whitespace |
| `\S` | `[^ \t\n\r\f\v]` | Non-whitespace |
| `\h` | `[ \t]` | Horizontal space (PCRE/Ruby) |
| `\N` | any non-newline | Portable dot alternative (PCRE) |
| `\R` | any line break | `\n`, `\r`, `\r\n`, etc. (PCRE) |

!!! note "\w and Unicode"
    In most ASCII-mode engines, `\w` only matches `[a-zA-Z0-9_]`. Under Unicode mode (Python's `re`, JS `/u`, etc.) it can include accented letters and script characters. This matters for international text.

---

## Custom Character Classes

```regex
# Match a hex digit
[0-9a-fA-F]

# Match everything except angle brackets
[^<>]

# Ranges: a-z, A-Z, 0-9 — ranges are ASCII-ordered
[A-Za-z_][A-Za-z0-9_]*    # valid identifier

# Literals inside classes: ] ^ - \ need special treatment
[]^-\\]    # matches ], ^, -, \
             # ^ negates ONLY at position 0
             # - is range ONLY between two chars

# Union of classes inside [] (all flavors)
[\d\s]     # digit OR whitespace
```

### Key rules inside `[…]`

- `^` at position 0 → negation. Anywhere else → literal `^`
- `-` between two chars → range. At start or end → literal `-`
- `]` must be escaped as `\]` (or placed first as `[]…]`)
- `\` always starts an escape

---

## POSIX Character Classes (ERE / PCRE)

| POSIX | Meaning |
|-------|---------|
| `[:alpha:]` | Letters (locale-aware) |
| `[:alnum:]` | Letters + digits |
| `[:digit:]` | Digits `[0-9]` |
| `[:lower:]` | Lowercase |
| `[:upper:]` | Uppercase |
| `[:space:]` | Whitespace (all) |
| `[:punct:]` | Punctuation |
| `[:print:]` | Printable characters |
| `[:xdigit:]` | Hex digits |
| `[:blank:]` | Space and tab only |

Usage: `[[:alpha:]]` — must double-bracket inside a character class.

---

## Unicode Property Escapes

Supported in PCRE, Python's `regex` module, Java, and JS with `/u` flag.

```regex
\p{L}               # any letter
\p{Lu}              # uppercase letter
\p{Ll}              # lowercase letter
\p{N}               # any number (including numerals)
\p{Z}               # separator (space-like)
\p{P}               # punctuation
\p{S}               # symbol (currency, math…)
\P{L}               # NOT a letter (capital P = negation)

# Script
\p{Script=Latin}
\p{Script=Cyrillic}
\p{Script=Han}

# Block (PCRE/Java)
\p{InGreek}
\p{InBasicLatin}
```

---

## Set Operations (JS `/v` flag, ES2024)

```js
// Intersection: letters that are also ASCII
/[\p{L}&&[\x00-\x7F]]/v

// Subtraction: letters except vowels
/[\p{L}--[aeiouAEIOU]]/v

// Nested character classes
/[[a-z][A-Z][0-9]]/v    // equivalent to [a-zA-Z0-9]
```
