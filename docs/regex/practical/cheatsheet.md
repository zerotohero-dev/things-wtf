# Quick Reference

A dense, scannable reference for all core regex syntax.

---

## Character Classes

| Pattern | Matches |
|---------|---------|
| `.` | Any char except `\n` (add `s` flag for `\n`) |
| `\d` | Digit `[0-9]` |
| `\D` | Non-digit |
| `\w` | Word char `[a-zA-Z0-9_]` |
| `\W` | Non-word char |
| `\s` | Whitespace `[ \t\n\r\f\v]` |
| `\S` | Non-whitespace |
| `[abc]` | Character set (a, b, or c) |
| `[^abc]` | Negated set (not a, b, or c) |
| `[a-z]` | Range: a through z |
| `\p{L}` | Any Unicode letter |
| `\p{N}` | Any Unicode number |
| `\p{Z}` | Unicode separator |

---

## Anchors

| Pattern | Position |
|---------|----------|
| `^` | Start of string (or line with `m` flag) |
| `$` | End of string (or line with `m` flag) |
| `\A` | Absolute string start (not JS) |
| `\Z` | Absolute string end, allows trailing `\n` (not JS) |
| `\z` | Strict string end, no trailing `\n` (not JS) |
| `\b` | Word boundary |
| `\B` | Non-word boundary |
| `\G` | End of previous match (PCRE, Java) |

---

## Quantifiers

| Quantifier | Meaning | Mode |
|------------|---------|------|
| `*` | 0 or more | Greedy |
| `+` | 1 or more | Greedy |
| `?` | 0 or 1 | Greedy |
| `{n}` | Exactly n | — |
| `{n,}` | n or more | Greedy |
| `{n,m}` | n to m | Greedy |
| `*?` `+?` `??` | Lazy versions | Minimal |
| `*+` `++` `?+` | Possessive | No backtrack |

---

## Groups

| Syntax | Type |
|--------|------|
| `(abc)` | Capturing group |
| `(?:abc)` | Non-capturing group |
| `(?<name>abc)` | Named capture |
| `(?P<name>abc)` | Named capture (Python/PCRE) |
| `\1`, `\2` | Backreference by number |
| `\k<name>` | Named backreference |

---

## Lookaround

| Syntax | Name |
|--------|------|
| `(?=abc)` | Positive lookahead |
| `(?!abc)` | Negative lookahead |
| `(?<=abc)` | Positive lookbehind |
| `(?<!abc)` | Negative lookbehind |

---

## Flags

| Flag | Effect |
|------|--------|
| `i` | Case-insensitive |
| `g` | Global (all matches) |
| `m` | Multiline (`^` `$` per line) |
| `s` | Dotall (`.` matches `\n`) |
| `x` | Verbose (whitespace + comments) |
| `u` | Unicode mode |

---

## Special Sequences

| Sequence | Meaning |
|----------|---------|
| `\n` | Newline |
| `\r` | Carriage return |
| `\t` | Tab |
| `\xHH` | Hex escape |
| `\uHHHH` | Unicode escape |
| `\u{HHHHH}` | Unicode code point (JS `/u`) |
| `\.` `\*` etc | Literal metacharacter |
| `\Q…\E` | Literal span (Java/PCRE) |

---

## PCRE Extensions

| Syntax | Meaning |
|--------|---------|
| `\K` | Reset match start |
| `(?R)` | Recurse entire pattern |
| `(?1)` | Recurse group 1 |
| `(?P>name)` | Recurse named group |
| `(?>…)` | Atomic group |
| `(?\|…)` | Branch reset |
| `(?#comment)` | Inline comment |
| `(*SKIP)(*FAIL)` | Match and discard |
| `(*ACCEPT)` | Force success |

---

## Language Quick Reference

=== "JavaScript"

    ```js
    /pattern/flags
    re.test(str)
    str.match(re)          // first match or all with /g (no groups)
    str.matchAll(re)       // all matches with groups (ES2020)
    str.replace(re, sub)
    str.split(re)
    re.exec(str)           // one match, advances lastIndex with /g
    ```

=== "Python"

    ```python
    import re
    re.match(r'pat', s)    # anchored to start
    re.search(r'pat', s)   # scan
    re.findall(r'pat', s)  # list of strings
    re.finditer(r'pat', s) # iterator of match objects
    re.sub(r'pat', r, s)   # replace
    re.split(r'pat', s)    # split
    ```

=== "Go"

    ```go
    import "regexp"
    re := regexp.MustCompile(`pattern`)
    re.MatchString(s)
    re.FindString(s)
    re.FindStringSubmatch(s)
    re.FindAllString(s, -1)
    re.ReplaceAllString(s, repl)
    re.Split(s, -1)
    ```

=== "Java"

    ```java
    import java.util.regex.*;
    Pattern p = Pattern.compile("pattern", flags);
    Matcher m = p.matcher(input);
    m.find()        // scan
    m.matches()     // full string
    m.group(n)      // nth capture
    m.group("name") // named capture
    ```

=== "PCRE / PHP"

    ```php
    preg_match('/pat/', $s, $m)
    preg_match_all('/pat/', $s, $m)
    preg_replace('/pat/', $r, $s)
    preg_replace_callback('/pat/', $fn, $s)
    preg_split('/pat/', $s)
    ```

---

## ReDoS Quick Check

Patterns that are **likely catastrophic** on untrusted input:

```regex
(a+)+        # ← nested quantifiers
(a|aa)+      # ← overlapping alternatives
(\w+\s*)+  # ← quantified group matching same chars as sibling
```

Fix: possessive (`a++`), atomic (`(?>a+)`), restructure, or switch to RE2.
