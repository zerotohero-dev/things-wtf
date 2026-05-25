# Regex — The Definitive Reference

> **From literals to lookaheads, from catastrophic backtracking to ReDoS hardening.**  
> Everything you need to think in regex.

A **regular expression** (regex) is a sequence of characters that defines a search pattern. They are a formal language rooted in Kleene's theory of regular sets (1956), later formalized by Ken Thompson into the first practical implementation for Unix's `ed` editor in 1968.

Despite the name, most modern "regex" engines far exceed true regular languages — they support backreferences, lookarounds, and recursion, making them computationally more powerful (and more dangerous) than pure finite automata.

---

## What Regex Can and Cannot Do

| ✓ Great for | ✗ Cannot parse | ⚠ Be careful with |
|---|---|---|
| Pattern matching, validation, extraction | Recursive structures (HTML/XML) | Untrusted input |
| Search-and-replace, tokenizing | Properly nested parens (without extensions) | Catastrophic backtracking |
| Log parsing, lightweight transforms | Context-sensitive grammar | Over-engineering simple string ops |

---

## Anatomy of a Pattern

```
/^(\d{4})-(0[1-9]|1[0-2])-(\d{2})$/gm
 │  │       │               │         │└─ flags
 │  │       │               │         └── delimiter (JS)
 │  │       │               └──────────── group 3: day
 │  │       └──────────────────────────── group 2: month (alternation)
 │  └──────────────────────────────────── group 1: year
 └─────────────────────────────────────── start anchor
```

---

## Guide Structure

This reference is organized into seven areas:

1. **[Foundations](foundations/syntax.md)** — syntax, character classes, anchors, quantifiers, alternation
2. **[Grouping](grouping/capturing-groups.md)** — captures, named groups, backreferences, lookarounds
3. **[Flags & Unicode](flags-unicode/flags.md)** — modifiers, Unicode property escapes, encoding traps
4. **[Advanced](advanced/greedy.md)** — greediness internals, atomic groups, conditionals, recursion
5. **[Engines](engines/nfa-dfa.md)** — NFA vs DFA, performance, catastrophic backtracking, ReDoS
6. **[Languages](languages/javascript.md)** — JS, Python, Go, Java, PCRE/PHP specifics
7. **[Practical](practical/patterns.md)** — production patterns, best practices, gotchas, cheat sheet

---

!!! tip "Start Here"
    New to regex? Read [Syntax Fundamentals](foundations/syntax.md) → [Characters & Classes](foundations/characters.md) → [Quantifiers](foundations/quantifiers.md) in order.  
    Experienced? Jump straight to [Catastrophic Backtracking](engines/backtracking.md) or the [Cheat Sheet](practical/cheatsheet.md).
