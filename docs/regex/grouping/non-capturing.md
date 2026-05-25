# Non-Capturing Groups

`(?:…)` groups without capturing. Use this when you need grouping for structure or quantifiers but don't need to extract the group.

**Benefits:**

- Faster — no capture allocation overhead
- Cleaner group numbering — downstream code that reads `m[2]` won't break when you add/remove groups
- Intent is explicit: reader knows this group is structural only

---

## Syntax

```regex
(?:foo|bar){2,4}       # alternation + quantifier, no capture
(?:https?|ftp)://      # URL scheme alternation
```

---

## Cleaning Up Group Numbering

```regex
# Bad: unnecessary capture pollutes numbering
(\d{4})-(0[1-9]|1[0-2])-(\d{2})    # groups 1,2,3 — month is group 2

# Better: month group is non-capturing
(\d{4})-(?:0[1-9]|1[0-2])-(\d{2})  # groups 1,2 — year and day only
```

---

## All Group Types at a Glance

| Syntax | Type | Support |
|--------|------|---------|
| `(?:…)` | Non-capturing | All |
| `(?<name>…)` | Named capture | PCRE, JS, Python, Java, .NET |
| `(?=…)` | Positive lookahead | All |
| `(?!…)` | Negative lookahead | All |
| `(?<=…)` | Positive lookbehind | PCRE, Python, Java, .NET, JS ES2018+ |
| `(?<!…)` | Negative lookbehind | Same as above |
| `(?>…)` | Atomic group | PCRE, Java, .NET, Ruby |
| `(?\|…)` | Branch reset | PCRE, PHP |
| `(?#…)` | Comment | PCRE, Python, Ruby |
| `(?x)` | Verbose mode inline | PCRE, Python |

---

## Inline Flags on Non-Capturing Groups

```regex
(?i:hello)       # case-insensitive only within this group
(?i)hello        # case-insensitive from this point forward
(?-i)            # turn off case-insensitivity
(?ims)           # multiple flags inline
(?i)Hello(?-i)World   # HELLO matches, World is case-sensitive
```
