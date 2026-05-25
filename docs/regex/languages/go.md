# Go

Go's `regexp` package uses **RE2 syntax**, which guarantees O(n) time by design. The tradeoff: no backreferences, no lookaheads/lookbehinds.

---

## Core API

```go
import "regexp"

// MustCompile — panics on bad pattern
// Use at package level or in init() so the panic happens at startup
var re = regexp.MustCompile(`(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})`)

// Compile — returns error
r, err := regexp.Compile(`\d+`)
if err != nil { /* invalid pattern */ }

// MatchString — bool
re.MatchString("2024-07-04")         // true

// FindString — first match string (empty string if no match)
re.FindString("date: 2024-07-04")    // "2024-07-04"

// FindStringIndex — [start, end] of first match
re.FindStringIndex("abc 2024 xyz")   // [4, 8]

// FindStringSubmatch — full match + all group captures
m := re.FindStringSubmatch("2024-07-04")
// m[0]="2024-07-04", m[1]="2024", m[2]="07", m[3]="04"

// FindAllString — all matches, -1 = no limit
re.FindAllString("2024-01 and 2024-07", -1)   // ["2024-01", "2024-07"]

// FindAllStringSubmatch — all matches with groups
re.FindAllStringSubmatch("2024-01", -1)

// ReplaceAllString — replace all matches
re.ReplaceAllString("foo 123 bar 456", "X")   // "foo X bar X"

// ReplaceAllStringFunc — dynamic replacement
re.ReplaceAllStringFunc("hello world", strings.ToUpper)   // "HELLO WORLD"

// ReplaceAllLiteralString — no backreference expansion in replacement
re.ReplaceAllLiteralString(input, "$1")    // replaces with literal "$1"

// Split
re.Split("a1b2c3", -1)    // ["a", "b", "c", ""]
```

---

## Named Groups in Go

Go uses `(?P<name>…)` syntax (Python-style):

```go
re := regexp.MustCompile(`(?P<year>\d{4})-(?P<month>\d{2})`)

m := re.FindStringSubmatch("2024-07")
names := re.SubexpNames()

// Build a name→value map
result := map[string]string{}
for i, name := range names {
    if i != 0 && name != "" {
        result[name] = m[i]
    }
}
// result["year"] = "2024", result["month"] = "07"
```

---

## Byte vs. String API

Every string method has a `[]byte` equivalent:

```go
re.Find(b []byte) []byte
re.FindAll(b []byte, n int) [][]byte
re.ReplaceAll(src, repl []byte) []byte
```

Use the `[]byte` API when working with file contents or network data to avoid unnecessary string allocations.

---

## RE2 Limitations

| Feature | Available? | Workaround |
|---------|-----------|-----------|
| Lookahead `(?=…)` | ✗ | Use `FindStringSubmatch` + post-filter in Go |
| Lookbehind `(?<=…)` | ✗ | Capture context + check in Go code |
| Backreferences `\1` | ✗ | Use `FindAllStringSubmatch`, compare in Go |
| Possessive quantifiers | ✗ | Not needed — no backtracking |
| Atomic groups | ✗ | Not needed — no backtracking |
| `\p{L}` Unicode properties | Limited | Basic categories work |

---

## Inline Flags

```go
regexp.MustCompile(`(?i)hello`)    // case-insensitive
regexp.MustCompile(`(?m)^foo`)     // multiline
regexp.MustCompile(`(?s).*`)       // dot matches newline
regexp.MustCompile(`(?i)(?m)^hello`)  // combine multiple
```

---

## Escaping for Dynamic Patterns

```go
import "regexp"

userInput := "price (USD)"
safe := regexp.QuoteMeta(userInput)    // "price \(USD\)"
re := regexp.MustCompile(safe)
```

---

## Performance Notes

- RE2 is O(n) — no catastrophic backtracking possible
- `MustCompile` / `Compile` is expensive — **always** cache compiled patterns
- The `regexp` package is not the fastest RE2 implementation; for high-throughput use cases consider `rure` (Rust RE2 via CGo) or Hyperscan bindings
- `regexp.MatchString(pattern, s)` compiles the pattern every call — never use in hot paths
