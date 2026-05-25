# Unicode & Encoding

Unicode support is one of the deepest gotcha zones in regex. Behavior varies drastically between engines and even between modes within the same engine.

---

## The Core Problem: Code Units vs. Code Points

| Concept | Meaning |
|---------|---------|
| **Byte** | 8-bit unit — what's stored on disk |
| **Code unit** | Engine's internal unit (16-bit in JS, 8-bit in Python 3 strings) |
| **Code point** | Unicode scalar value (U+0000 to U+10FFFF) |
| **Grapheme cluster** | What a human perceives as one "character" |

Regex engines typically operate on **code units**, not grapheme clusters.

---

## Astral Plane / Surrogate Pairs

Characters outside the BMP (U+10000+, including most emoji) are encoded as **surrogate pairs** in UTF-16. Without the Unicode flag, JavaScript's regex treats each surrogate as a separate character:

```js
// Without /u — surrogates split emoji
/^.$/.test("😀")    // false — it's 2 code units
/^.$/u.test("😀")   // true  — /u = Unicode code point mode

// Counting characters
[..."Hello 😀"].length   // 8 — spread uses code points
"😀".length              // 2 — two UTF-16 code units

// Match any emoji (JS /u or /v flag)
/\p{Emoji}/u.test("😀")    // true
```

---

## Unicode Normalization

The letter **é** can be encoded as:

- A single codepoint: U+00E9 (precomposed NFC)
- Two codepoints: `e` (U+0065) + combining accent (U+0301) (decomposed NFD)

These look identical but are different byte sequences. Most regex engines compare bytes, not grapheme clusters.

```js
// JS: always normalize before matching Unicode text
str.normalize('NFC').match(/é/u)

// Python
import unicodedata
unicodedata.normalize('NFC', s)
```

---

## Grapheme Clusters

A "perceived character" like **👩‍💻** is actually multiple codepoints joined by Zero-Width Joiners (ZWJ). The pattern `.` matches **one code point**, not one grapheme:

```
"👩‍💻" = U+1F469 + U+200D + U+1F4BB   (3 codepoints)
```

For grapheme-level operations, use:

- Swift's `StringProtocol` (grapheme cluster aware by default)
- ICU-based libraries
- Python's `grapheme` package
- JavaScript's `Intl.Segmenter`

---

## `\p{}` — Unicode Property Escapes

| Property | Matches |
|----------|---------|
| `\p{L}` | Any letter |
| `\p{Lu}` | Uppercase letter |
| `\p{Ll}` | Lowercase letter |
| `\p{N}` | Any number |
| `\p{Z}` | Separator (space-like) |
| `\p{P}` | Punctuation |
| `\p{S}` | Symbol |
| `\P{L}` | NOT a letter (uppercase P = negation) |
| `\p{Script=Latin}` | Latin script |
| `\p{Script=Han}` | CJK characters |
| `\p{Emoji}` | Emoji (JS /u) |

---

## Case-Insensitive Matching and Unicode

!!! warning "Locale Traps"
    Uppercase `İ` (Turkish I with dot, U+0130) lowercases to `i`, but lowercase `i` uppercases to `İ` in Turkish locale — not plain `I`.  
    Use explicit Unicode-aware case folding when operating on international text.

```js
/file/i.test("FİLE")    // may be true in TR locale, false in EN
```

---

## Engine Unicode Support Summary

| Engine | `\p{}` support | Grapheme clusters | Normalization |
|--------|----------------|-------------------|--------------|
| JS `/u` | ✓ (limited) | ✗ | Manual |
| JS `/v` | ✓ (extended) | ✗ | Manual |
| Python `re` | ✗ (use `regex`) | ✗ | Manual |
| Python `regex` | ✓ | ✓ | Manual |
| Java | ✓ (via `Pattern.UNICODE_CHARACTER_CLASS`) | ✗ | Manual |
| PCRE2 | ✓ | ✓ (`\X`) | Manual |
| Go RE2 | Limited | ✗ | Manual |
