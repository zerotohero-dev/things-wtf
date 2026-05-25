# NFA vs. DFA Engines

The two main engine architectures have fundamentally different performance characteristics and feature sets.

---

## Comparison Table

| Attribute | NFA (Backtracking) | DFA (Thompson/RE2) |
|-----------|--------------------|--------------------|
| Algorithm | Depth-first search with backtracking | Simulates all states in parallel |
| Worst case | O(2^n) — exponential | O(n) — linear in string length |
| Backreferences | ✓ Supported | ✗ Not supported |
| Lookarounds | ✓ Supported | ✗ Not supported (or limited) |
| Full captures | ✓ | Limited (leftmost-longest) |
| Match semantics | Leftmost, first-match | Leftmost-longest (POSIX) |
| Used by | PCRE, JS, Python, Java, .NET, Ruby | RE2 (Go), Rust regex, Hyperscan |
| ReDoS vulnerable | Yes | **No — by design** |

---

## How NFA Works

The NFA (Non-deterministic Finite Automaton) engine explores match paths depth-first. When it hits an ambiguity (quantifier, alternation), it chooses one path and backtracks if it fails.

```
Pattern: (a|ab)c
Input:   "abc"

Path 1: match 'a', try 'c' at 'b' → fail
Backtrack: try 'ab', try 'c' at 'c' → success
Result: "abc"
```

NFA engines are **feature-rich** (backreferences, lookarounds, atomic groups) but can exhibit exponential behavior on adversarial input.

---

## How DFA / RE2 Works

The DFA (Deterministic Finite Automaton) engine — or Thompson NFA simulation — processes the input **left to right, one character at a time**, tracking all possible states simultaneously.

```
Pattern: (a|ab)c
Input:   "abc"

At each position, ALL possible states are tracked in parallel.
No backtracking — the engine never re-reads a character.
Time: O(n) regardless of pattern complexity.
```

The cost: **no backreferences, no lookarounds**. Features that require "remembering" what was matched at a specific point are fundamentally incompatible with the DFA model.

---

## POSIX vs. Perl Semantics

```
Pattern: (foo|foobar) against "foobar"

Perl/PCRE/JS → "foo"    (first alternative wins — leftmost)
POSIX        → "foobar" (longest overall match — leftmost-longest)
```

Most modern tools (grep, sed, awk in POSIX mode) use leftmost-longest semantics. Most programming language regex libraries use Perl/PCRE semantics.

---

## Go's RE2 Engine

Go's `regexp` package uses RE2, which guarantees O(n) time. The tradeoff: no backreferences, no lookaheads/lookbehinds.

```go
// Will compile only if pattern is RE2-safe
r, err := regexp.Compile(`(?P<year>\d{4})-(?P<month>\d{2})`)
// Pattern with backreference → compile error
r, err = regexp.Compile(`(\w+)\s+\1`)    // error: invalid backreference
```

For security-sensitive applications processing untrusted input, RE2/linear engines are the right choice.

---

## Rust's `regex` Crate

Also O(n) — uses NFA simulation (no backtracking). Same limitations as RE2: no backreferences, no lookarounds. Extremely fast in practice.

---

## Hybrid Engines

Some engines detect patterns that can be compiled to a DFA and use the fast path, falling back to NFA for patterns requiring backtracking features. .NET's regex engine, Oniguruma, and some PCRE2 configurations do this.

---

## Choosing an Engine

| Situation | Recommended engine |
|-----------|-------------------|
| Untrusted input, must not hang | RE2 / Go / Rust |
| Need backreferences | PCRE, Java, .NET |
| Need lookarounds | PCRE, Python, Java, .NET, JS |
| High throughput, simple patterns | RE2, Hyperscan |
| Complex patterns, trusted input | PCRE, Java |
