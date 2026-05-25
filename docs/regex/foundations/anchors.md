# Anchors & Boundaries

Anchors assert **positions** in the string, not characters. They consume zero characters (zero-width assertions).

---

## Anchor Reference

| Anchor | Position | Notes |
|--------|----------|-------|
| `^` | Start of string (or line in multiline) | Without `m` flag, matches only string start |
| `$` | End of string (or line in multiline) | Often allows trailing `\n` |
| `\A` | Absolute start of string | Unaffected by multiline. Not available in JS |
| `\Z` | Absolute end of string | May allow trailing `\n` (Python). Not JS |
| `\z` | Strict end of string | No trailing newline. Ruby/PCRE/Java |
| `\b` | Word boundary | Between `\w` and `\W` (or string start/end) |
| `\B` | Non-word boundary | Inside a word or inside whitespace |
| `\G` | End of previous match | For consecutive extraction. PCRE, Java |

---

## Word Boundary Deep Dive

`\b` is a zero-width assertion that succeeds where a word character (`\w`) is adjacent to a non-word character (or start/end of string).

```regex
\bcat\b
```

| Input | Matches? | Reason |
|-------|----------|--------|
| `"I have a cat."` | ✓ `cat` | Surrounded by non-word chars |
| `"catfish"` | ✗ | No boundary after `t` |
| `"concatenate"` | ✗ | No boundary around `cat` |
| `"scat"` | ✗ | No leading boundary |

```regex
\b\d+\b    # whole numbers only (not inside "abc123def")
```

!!! warning "\b and Unicode"
    `\b` is defined relative to `\w`, which is ASCII-only in most engines unless Unicode mode is active.  
    `\bhéros\b` may not work as expected — the accented `é` is `\W` in ASCII mode, so the boundary fires *inside* the word.  
    Use Unicode-aware engines or explicit anchors for international text.

---

## Multiline vs. Single-line

```js
// Without m flag — only one ^ and $
/^hello$/.test("hello\nworld")   // false

// With m flag — ^ and $ match at each \n
/^hello$/m.test("hello\nworld")  // true

// \A and \z for absolute boundaries regardless of m
/\Ahello\z/m    // still only matches single-line "hello"
```

---

## The `$` Trailing Newline Trap

Most engines allow `$` to match *before* an optional trailing newline:

```python
import re
re.match(r'^\d+$', '123\n')   # matches! $ allows trailing \n
re.match(r'^\d+\Z', '123\n') # None — \Z is strict end
```

Use `\Z` (Python/PCRE) or `\z` (Ruby/Java) when you need strict end-of-string without any newline tolerance.

---

## `\G` — Contiguous Matching

`\G` asserts the position is at the *end of the previous match*. Used with global/repeated matching to enforce that matches are contiguous.

```java
// Java — tokenizer using \G
Pattern p = Pattern.compile("\\G(\\w+)\\s*");
Matcher m = p.matcher("foo bar baz");
while (m.find()) {
    System.out.println(m.group(1));  // foo, bar, baz — contiguous only
}
```
