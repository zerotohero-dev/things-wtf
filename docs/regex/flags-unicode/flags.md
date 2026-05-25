# Flags / Modifiers

Flags change how the engine interprets the pattern or the input.

---

## Flag Reference

| Flag | Symbol | Effect | Support |
|------|--------|--------|---------|
| `i` | Ignore case | Case-insensitive matching | All |
| `g` | Global | Find all matches, not just first | JS, some others |
| `m` | Multiline | `^` and `$` match line starts/ends | All |
| `s` | Dotall / Single-line | `.` matches `\n` too | PCRE, Python, JS ES2018, Java |
| `x` | Verbose / Extended | Allow whitespace and `#` comments | PCRE, Python, Ruby, Java |
| `u` | Unicode | Full Unicode matching; needed for `\p{}` | JS ES6, PCRE |
| `v` | UnicodeSets | Extended Unicode, set operations in `[]` | JS ES2024 |
| `d` | Indices | Include start/end indices in match result | JS ES2022 |
| `y` | Sticky | Match only at `lastIndex` position | JS |
| `A` | Anchored | Force match at start (like `\A`) | PCRE |

---

## Verbose Mode (`x` flag)

Verbose mode lets you write readable, commented patterns. Whitespace is ignored (unless escaped or in a character class) and `#` introduces line comments.

```python
# Python — verbose date pattern
date_re = re.compile(r'''
  (?P<year>\d{4})    # 4-digit year
  -                   # separator
  (?P<month>          # month:
    0[1-9]            #   01–09
    |1[0-2]           #   10–12
  )
  -                   # separator
  (?P<day>\d{2})     # day
''', re.VERBOSE)
```

```php
// PCRE in PHP
$re = '/
  \b
  (?:\d{1,3}\.){3}   # first three octets
  \d{1,3}             # last octet
  \b
/x';
```

---

## Inline Mode Modifiers

Apply flags to a portion of the pattern using inline syntax:

```regex
(?i)hello             # case-insensitive from this point
(?i:hello)            # case-insensitive only inside this group
(?-i)                 # turn off case-insensitivity
(?ims)                # multiple flags inline
(?i)Hello(?-i)World   # HELLO matches, World is case-sensitive
```

---

## The `g` Flag and `lastIndex` (JS)

!!! warning "Stateful Regex in JS"
    The `g` flag makes JavaScript's `exec()` stateful — it advances `lastIndex` after each call.  
    Reusing a `/g` regex without resetting `lastIndex` causes subtle bugs.

```js
const re = /\d+/g;
re.exec("12 34");   // ["12"]  — lastIndex = 2
re.exec("12 34");   // ["34"]  — lastIndex = 5
re.exec("12 34");   // null   — resets lastIndex to 0
re.exec("12 34");   // ["12"] — starts over!

// Fix: reset manually or use matchAll
re.lastIndex = 0;
```

---

## The `y` Sticky Flag (JS)

`/y` only matches at the exact `lastIndex` position — it does not scan:

```js
const re = /\d+/y;
re.lastIndex = 3;
re.exec("abc123")   // ["123"] — matched at position 3
re.lastIndex = 0;
re.exec("abc123")   // null    — no digits at position 0
```

Useful for building hand-rolled tokenizers that need to enforce contiguous, non-scanning matching.

---

## Flags by Engine

| Flag | JS | Python | Go | Java | PCRE |
|------|----|--------|----|------|------|
| `i` ignore case | ✓ | `re.I` | `(?i)` | `CASE_INSENSITIVE` | `(?i)` |
| `m` multiline | ✓ | `re.M` | `(?m)` | `MULTILINE` | `(?m)` |
| `s` dotall | ES2018 | `re.S` | `(?s)` | `DOTALL` | `(?s)` |
| `x` verbose | ✗ | `re.X` | ✗ | `COMMENTS` | `(?x)` |
| `g` global | ✓ | (findall) | (FindAll) | (loop) | (g modifier) |
