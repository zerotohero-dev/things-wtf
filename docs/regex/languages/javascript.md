# JavaScript

JavaScript has a rich built-in regex implementation with unique features and some surprising quirks.

---

## Core Methods

```js
// ── test — returns boolean ──────────────────────────────────
/^\d+$/.test("123")               // true
/^\d+$/.test("abc")               // false

// ── exec — returns match object (advances lastIndex with /g) ──
const re = /\d+/g;
let m;
while ((m = re.exec("12 and 34")) !== null) {
  console.log(m[0], m.index);    // "12" 0, "34" 7
}

// ── match — all matches with /g, first match object without ──
"12 and 34".match(/\d+/g)        // ["12", "34"]
"12 and 34".match(/(\d+)/)       // ["12", "12", index:0, groups:undefined]

// ── matchAll (ES2020) — iterator of all match objects ────────
const matches = [..."12 and 34".matchAll(/(\d+)/g)];
// Each element is a full match object with groups

// ── replace — first match (or all with /g) ──────────────────
"hello world".replace(/\w+/g, s => s.toUpperCase());  // "HELLO WORLD"

// ── replaceAll (ES2021) ──────────────────────────────────────
"a-b-c".replaceAll("-", "_");     // "a_b_c"  (string literal only)

// ── split ───────────────────────────────────────────────────
"one1two2three".split(/\d/)       // ["one", "two", "three"]
"one1two2".split(/(\d)/)          // ["one","1","two","2",""] — captured delimiters included
```

---

## The `lastIndex` Trap

```js
// /g flag with exec mutates lastIndex — reuse without resetting is a bug
const re = /\d+/g;
re.exec("12 34");   // ["12"]  — lastIndex = 2
re.exec("12 34");   // ["34"]  — lastIndex = 5
re.exec("12 34");   // null   — resets lastIndex to 0
re.exec("12 34");   // ["12"] — starts over!

// Fix: always reset or use matchAll
re.lastIndex = 0;
// Or: use a fresh regex for one-shot operations
```

!!! warning "`match()` with `/g` drops group captures"
    `"foo bar".match(/(\w+)/g)` returns `["foo", "bar"]` — groups are lost.  
    Use `matchAll()` to get match objects with groups in global mode.

---

## Named Captures (ES2018)

```js
const { groups } = "2024-07-04".match(
  /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/
);
// groups.year = "2024", groups.month = "07", groups.day = "04"

// Named groups in replacement string
"2024-07-04".replace(
  /(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})/,
  '$<d>/$<m>/$<y>'
);  // "04/07/2024"
```

---

## Sticky Flag `/y`

```js
// /y only matches at re.lastIndex — no scanning
const re = /\d+/y;
re.lastIndex = 3;
re.exec("abc123")   // ["123"] — matched at position 3
re.lastIndex = 0;
re.exec("abc123")   // null    — no digits at position 0
```

Useful for hand-rolled tokenizers that need to enforce contiguous, non-scanning matching.

---

## Indices Flag `/d` (ES2022)

```js
const m = "2024-07-04".match(/(?<year>\d{4})-(?<month>\d{2})/d);
m.indices[0]          // [0, 7]  — full match start/end
m.indices.groups.year // [0, 4]  — named group start/end
```

---

## Constructing Regex Dynamically

```js
// new RegExp takes a string — backslashes must be doubled
const pattern = "\\d{4}";          // string contains: \d{4}
const re = new RegExp(pattern, "g"); // regex: /\d{4}/g

// Escaping user input for use in dynamic regex
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
const userSearch = "price (USD)";
const re = new RegExp(escapeRegex(userSearch), "gi");
```

---

## Version Compatibility

| Feature | ES version | Notes |
|---------|-----------|-------|
| Named captures `(?<name>…)` | ES2018 | Also `\k<name>` backreference |
| Lookbehind `(?<=…)` `(?<!…)` | ES2018 | Not available in older engines |
| `s` dotall flag | ES2018 | `.` matches `\n` |
| `matchAll()` | ES2020 | |
| `d` indices flag | ES2022 | |
| `v` UnicodeSets flag | ES2024 | Set operations in `[]` |
| `/u` Unicode flag | ES2015 | Required for `\p{}` and astral chars |

---

## JS-Specific Gotchas

- `/regex/` literals compile at parse time — prefer them over `new RegExp()` when the pattern is static.
- No possessive quantifiers or atomic groups — restructure patterns instead.
- `String.prototype.search()` always resets `lastIndex` to 0.
- `split()` with a capturing group includes the captured text in the result array (intentional, but surprising).
