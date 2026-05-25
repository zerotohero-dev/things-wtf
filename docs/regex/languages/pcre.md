# PCRE / PHP

PCRE (Perl Compatible Regular Expressions) is the most feature-rich engine family, used in PHP, Nginx, Apache, Perl, R, and dozens of other tools. PCRE2 is the current version.

---

## PHP — `preg_*` Functions

```php
// ── preg_match — first match ──────────────────────────────────
preg_match('/(?P<year>\d{4})-(?P<month>\d{2})/', '2024-07', $m);
// $m[0] = '2024-07', $m['year'] = '2024', $m[1] = '2024'

// ── preg_match_all — all matches ──────────────────────────────
preg_match_all('/\d+/', '12 and 34', $matches);
// $matches[0] = ['12', '34']

// With PREG_SET_ORDER — more convenient grouping
preg_match_all('/(\d+)(\w)/', '12x 34y', $m, PREG_SET_ORDER);
// $m[0] = ['12x', '12', 'x']
// $m[1] = ['34y', '34', 'y']

// ── preg_replace ──────────────────────────────────────────────
preg_replace('/\d+/', 'X', 'a1b2c3');            // 'aXbXcX'
preg_replace('/(?P<y>\d{4})-(?P<m>\d{2})/', '${m}/${y}', '2024-07');  // '07/2024'

// ── preg_replace_callback ────────────────────────────────────
preg_replace_callback('/\d+/', function($m) {
    return $m[0] * 2;
}, 'a1b2c3');   // 'a2b4c6'

// ── preg_split ───────────────────────────────────────────────
preg_split('/\s+/', 'a b  c');   // ['a', 'b', 'c']
```

---

## PCRE-Exclusive Features

### `\K` — Match Reset

`\K` discards everything matched so far, acting like a variable-length lookbehind:

```regex
price:\s*\K[\d.]+
# Matches only the number, not "price: " prefix
# More flexible than lookbehind — no length restriction
```

### Possessive Quantifiers

```regex
\d++        # digits possessively
[a-z]++      # lowercase letters possessively
(?:ab)++     # group possessively
```

### Atomic Groups

```regex
(?>\d+)     # match digits atomically — no backtracking into this group
```

### Recursive Patterns

```regex
# Balanced parentheses
\((?:[^()]|(?R))*\)

# Recurse into a named group
(?P<paren>\((?:[^()]|(?P>paren))*\))

# Nested square brackets
\[(?:[^\[\]]|(?R))*\]
```

### Branch Reset `(?|…)`

All alternatives share the same group numbers:

```regex
(?|(Mon)day|(Tue)sday|(Wed)nesday)
# Always group 1, regardless of which alternative matched
```

### Subroutine Calls

Reuse a named group's pattern (not its captured text):

```regex
(?(DEFINE)
  (?P<octet>25[0-5]|2[0-4]\d|[01]?\d\d?)
)
^(?P>octet)\.(?P>octet)\.(?P>octet)\.(?P>octet)$
# IPv4 — octet defined once, used four times
```

### Backtracking Control Verbs

```regex
# (*SKIP)(*FAIL) — match but don't consume (useful for exclusion)
"[^"]*"(*SKIP)(*FAIL)|\bword\b
# Match "word" only OUTSIDE quoted strings

# Other verbs
(*PRUNE)    # cut off current branch at this point
(*COMMIT)   # don't backtrack into alternatives before this point
(*THEN)     # try next alternative in current group
(*ACCEPT)   # force overall match success from current position
(*FAIL)     # force failure (can also write (?!))
```

### Conditional Patterns

```regex
(<)?[^<>]+(?(1)>)
# If group 1 captured "<", require closing ">"
# Matches "<hello>" or "hello", but not "<hello"
```

### PCRE2 Callouts

```regex
foo(?C1)bar
# Calls a user-defined callback function at (?C1)
# Useful for debugging or custom validation logic
```

---

## PCRE Flags

| Flag | Inline | Effect |
|------|--------|--------|
| `i` | `(?i)` | Case-insensitive |
| `m` | `(?m)` | Multiline |
| `s` | `(?s)` | Dotall |
| `x` | `(?x)` | Verbose |
| `u` | `(*UTF)` | UTF-8 mode |
| `A` | `(*ANYCRLF)` | Anchor to start |
| `U` | `(?U)` | Ungreedy by default |

---

## PCRE in Other Contexts

```nginx
# Nginx — PCRE syntax in location blocks
location ~ ^/api/(?P<version>v[0-9]+)/(?P<resource>[a-z]+) {
    proxy_pass http://backend;
}

# Apache mod_rewrite
RewriteRule ^/old/(.+)$ /new/$1 [R=301,L]

# grep with PCRE
grep -P '(?<=prefix_)\w+' file.txt
```
