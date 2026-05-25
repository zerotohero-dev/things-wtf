# Syntax Fundamentals

Every character in a regex is either a **literal** (matches itself) or a **metacharacter** (has special meaning).

Only 12 metacharacters need escaping outside character classes:

```
\ ^ $ . | ? * + ( ) [ ] { }
```

---

## Literals and Escaping

Most characters match themselves. To use a metacharacter literally, prefix with `\`.

```regex
hello\.world    # matches "hello.world" literally
                 # unescaped . would match "helloXworld" too
```

---

## The Dot `.`

Matches any single character **except** a newline (unless the `s` / DOTALL flag is set).

!!! warning "Most Overused Token"
    The dot is the most overused token in regex. `.*` is greedy, slow on backtracking, and matches far more than you usually intend.  
    Use `[^,]*` or a specific character class wherever possible.

---

## Escape Sequences

| Sequence | Matches | Example |
|----------|---------|---------|
| `\n` | Newline (LF) | `"line1\nline2"` |
| `\r` | Carriage return | Windows line endings |
| `\t` | Tab | TSV fields |
| `\f` | Form feed | Page breaks |
| `\v` | Vertical tab | Old format characters |
| `\0` | Null byte | Binary data |
| `\xHH` | Hex codepoint | `\x41` → `A` |
| `\uHHHH` | Unicode (4-hex) | `\u00e9` → `é` |
| `\u{HHHHH}` | Unicode (ES6 / u flag) | `\u{1F600}` → 😀 |
| `\a` | Bell (PCRE) | Terminal bell |
| `\e` | Escape char (PCRE) | ANSI escape sequences |

---

## The Structure of a Regex

```
Pattern:   /^(\d{1,3}\.){3}\d{1,3}$/i
            │  └──────────┘    └──────┘ └ flags
            │  group + quant   literal
            anchor
```

Every regex is a sequence of:

- **Atoms** — a character, class, or group
- **Quantifiers** — how many times an atom repeats
- **Anchors** — zero-width position assertions
- **Alternation** — the `|` OR operator between sequences

---

## Syntax Across Flavors

Most engines share PCRE-ish syntax. Key divergences:

| Feature | JS | Python | Go | PCRE |
|---------|----|--------|----|------|
| Named groups | `(?<name>…)` | `(?P<name>…)` | `(?P<name>…)` | `(?<name>…)` |
| Named backref | `\k<name>` | `(?P=name)` | N/A | `\k<name>` |
| Atomic group | ✗ | ✗ | ✗ | `(?>…)` |
| Lookbehind | ES2018+ | ✓ | ✗ | ✓ |
| Unicode props | `/u` flag | `\p{}` via `regex` | ✗ | `\p{}` |
