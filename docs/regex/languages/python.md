# Python

Python has two regex modules: the standard `re` (NFA) and the third-party `regex` (extended features including possessive quantifiers, Unicode properties, fuzzy matching, and variable-length lookbehinds).

---

## Core `re` API

```python
import re

# Compile for reuse (always do this for hot paths)
pattern = re.compile(r'\b\w+\b', re.IGNORECASE)

# ── match — anchored to START of string ─────────────────────
m = re.match(r'\d+', '123 abc')   # matches — m.group() = '123'
m = re.match(r'\d+', 'abc 123')   # None — doesn't scan forward

# ── search — first match anywhere ───────────────────────────
m = re.search(r'\d+', 'abc 123')  # m.group() = '123'

# ── findall — list of strings (tuples if groups) ────────────
re.findall(r'\d+', '12 and 34')        # ['12', '34']
re.findall(r'(\d+)(\w)', '12x 34y')   # [('12','x'), ('34','y')]

# ── finditer — iterator of match objects ────────────────────
for m in re.finditer(r'\d+', '12 34'):
    print(m.group(), m.start(), m.end())

# ── sub — replace ────────────────────────────────────────────
re.sub(r'\d+', 'X', 'a1b23c')                      # 'aXbXc'
re.sub(r'(\w+)', lambda m: m.group().upper(), 'hi') # 'HI'
re.sub(r'(\w+)', r'[\1]', 'hello')                 # '[hello]'

# ── subn — sub + return count ────────────────────────────────
result, count = re.subn(r'\d', 'X', 'a1b2c3')      # ('aXbXcX', 3)

# ── split ────────────────────────────────────────────────────
re.split(r'\s+', 'a b  c')            # ['a', 'b', 'c']
re.split(r'(\s+)', 'a b  c')          # ['a', ' ', 'b', '  ', 'c']
re.split(r'\s+', 'a b  c', maxsplit=1) # ['a', 'b  c']
```

---

## Flags

```python
re.IGNORECASE   # (re.I)  — case-insensitive
re.MULTILINE    # (re.M)  — ^ and $ match per line
re.DOTALL       # (re.S)  — . matches \n
re.VERBOSE      # (re.X)  — whitespace and # comments
re.ASCII        # (re.A)  — \w, \d, \b, \s match ASCII only
re.UNICODE      # (re.U)  — default in Python 3
# Combine with |
re.compile(r'pattern', re.I | re.M)
```

---

## Named Groups

```python
m = re.match(r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})', '2024-07-04')
m.group('year')    # '2024'
m.group('month')   # '07'
m.groupdict()      # {'year': '2024', 'month': '07', 'day': '04'}

# Named backreference in pattern
re.search(r'\b(?P<word>\w+)\s+(?P=word)\b', 'the the')   # matches

# Named group in replacement
re.sub(r'(?P<y>\d{4})-(?P<m>\d{2})', r'\g<m>/\g<y>', '2024-07')
# → '07/2024'
```

---

## Verbose Mode

```python
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

---

## The `regex` Module (Third-Party)

Install: `pip install regex`

Key additions over `re`:

```python
import regex

# Possessive quantifiers
regex.match(r'\d++', '123abc')

# Variable-length lookbehind
regex.search(r'(?<=\w+:)\d+', 'version:42')

# Unicode properties
regex.findall(r'\p{L}+', 'hello мир 世界')   # ['hello', 'мир', '世界']

# Fuzzy matching
regex.match(r'(?:hello){e<=1}', 'helo')   # allow 1 error

# Timeout
try:
    regex.match(pattern, input, timeout=0.5)
except regex.TimeoutError:
    pass  # input too complex
```

---

## Python Gotchas

!!! warning "Always Use Raw Strings"
    ```python
    re.compile('\d+')    # Python interprets \d as \x08 + 'd' (bad)
    re.compile(r'\d+')   # raw string: \d is two chars, passed as-is (good)
    ```

!!! warning "match() is Anchored"
    `re.match()` only matches at the start of the string — it's effectively `^pattern`.  
    Use `re.search()` for scanning behavior. This surprises almost everyone.

!!! info "findall() with Groups Returns Tuples"
    ```python
    re.findall(r'(\d+)(\w)', '12x')   # [('12', 'x')] — not ['12x']
    re.findall(r'\d+\w', '12x')       # ['12x'] — no groups
    ```
