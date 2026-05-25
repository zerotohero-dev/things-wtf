# Capturing Groups

Parentheses `(…)` serve two purposes: **grouping** (applying quantifiers or alternation to a subpattern) and **capturing** (saving the matched substring for later use).

Groups are numbered left-to-right by their **opening parenthesis**, starting at 1. Group 0 is always the entire match.

---

## Basic Usage

```js
// JS: extracting date parts
const m = "2024-03-15".match(/^(\d{4})-(\d{2})-(\d{2})$/);
// m[0] = "2024-03-15"  (full match)
// m[1] = "2024"        (group 1)
// m[2] = "03"          (group 2)
// m[3] = "15"          (group 3)
```

```python
# Python
m = re.match(r'^(\d{4})-(\d{2})-(\d{2})$', '2024-03-15')
m.group(1)  # '2024'
m.group(2)  # '03'
m.groups()  # ('2024', '03', '15')
```

---

## Nested Groups — Numbering

```regex
(a(b(c)))    # groups: 1=abc, 2=bc, 3=c
             # outer-to-inner, left-to-right opening paren

((a)(b))     # groups: 1=ab, 2=a, 3=b
```

The rule: **count opening parentheses left to right** to get the group number.

---

## Repeated Groups

```js
// A group inside a quantifier captures only the LAST iteration
const m = "aababc".match(/([a-c]+){3}/);
// m[1] = "c" — only the last repetition
```

To capture all iterations, use `matchAll()` or a loop with `exec()`.

---

## Group 0 — The Full Match

In every language, group/match index `0` is always the entire matched string:

```js
"hello world".match(/(\w+)\s(\w+)/)[0]  // "hello world"
"hello world".match(/(\w+)\s(\w+)/)[1]  // "hello"
"hello world".match(/(\w+)\s(\w+)/)[2]  // "world"
```

---

## When a Group Doesn't Participate

In alternation, some groups may not participate:

```js
const m = "cat".match(/(cat)|(dog)/);
// m[1] = "cat"
// m[2] = undefined  — group 2 didn't participate
```

Check for `undefined` / `None` before using group values.
