# Conditionals & Recursion

These features take regex well beyond regular languages. Primary support is in PCRE, .NET, and JGsoft flavors.

---

## Conditional Patterns

**Syntax:** `(?(condition)yes|no)`

The condition can be a group number (was group N captured?) or an inline lookahead/lookbehind.

```regex
# If group 1 captured "<", require closing ">"
(<)?[^<>]+(?(1)>)
# Matches: "<hello>" and "hello", but not "<hello"

# Conditional on lookahead
(?(?=\d)\d{4}|[A-Z]{4})
# If next char is a digit, match 4 digits; otherwise 4 letters

# Conditional on named group
(?(<q>)"|')   # if group "q" captured, match ", else match '
```

---

## Branch Reset `(?|…)` (PCRE/PHP)

All alternatives inside `(?|…)` share the same group numbers:

```regex
(?|(Mon)|(Tue)|(Wed)|(Thu)|(Fri))   # always group 1, whichever matched
# vs. normal (Mon)|(Tue) which would be groups 1 and 2
```

Useful when you want a single group index regardless of which alternative fired.

---

## Recursive Patterns (PCRE)

PCRE supports recursion via `(?R)` (recurse entire pattern) or `(?1)` / `(?P>name)` (recurse into a specific group):

```regex
# Match balanced parentheses — not possible in true regex!
\((?:[^()]|(?R))*\)

# Recurse into a named group
(?P<paren>\((?:[^()]|(?P>paren))*\))

# Match nested square brackets
\[(?:[^\[\]]|(?R))*\]
```

How it works: `(?R)` inserts the entire pattern at that position, allowing the pattern to match itself recursively. This enables matching of arbitrarily nested structures.

!!! warning "Use Sparingly"
    Recursive patterns are powerful but hard to read, debug, and reason about performance for.  
    For truly recursive structures (JSON, XML, nested parens in production code), use a proper parser.  
    Recursive regex is mainly useful for quick scripts or prototyping.

---

## PCRE Subroutine Calls

Reuse a named group's *pattern* (not its captured text — that's a backreference):

```regex
# Define a pattern once, use it multiple times
(?(DEFINE)(?P<octet>25[0-5]|2[0-4]\d|[01]?\d\d?))
^(?P>octet)\.(?P>octet)\.(?P>octet)\.(?P>octet)$
# IPv4 — octet pattern defined once, reused 4 times
```

---

## `(*SKIP)(*FAIL)` (PCRE Verbs)

Backtracking control verbs let you match something and then explicitly reject it:

```regex
"[^"]*"(*SKIP)(*FAIL)|\bword\b
# Matches "word" only OUTSIDE quoted strings
# Quoted strings are matched first, then (*SKIP)(*FAIL) forces them to be skipped
```

This is far cleaner than trying to write a negative lookbehind/lookahead that accounts for variable-length quoted strings.

---

## Engine Support Summary

| Feature | PCRE | .NET | Java | JS | Python | Go |
|---------|------|------|------|----|---------|----|
| Conditionals `(?(…)…)` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| Recursion `(?R)` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Branch reset `(?\|…)` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `(*SKIP)(*FAIL)` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Subroutines `(?P>…)` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
