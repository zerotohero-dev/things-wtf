# Alternation

The pipe `|` is the OR operator. It has the **lowest precedence** of all regex operators — lower than concatenation, lower than quantifiers.

---

## Basic Alternation

```regex
cat|dog          # "cat" OR "dog"
cat|dogfish      # "cat" OR "dogfish" — not "cat|dog" + "fish"
^cat|dog$        # ("^cat") OR ("dog$") — anchors bind before |
^(cat|dog)$      # correct: entire string must be "cat" or "dog"
```

---

## Ordering Matters (NFA Engines)

!!! warning "Left-to-Right Short-Circuit"
    In NFA-based engines (most modern ones), alternation tries alternatives **left to right** and stops at the first match.

    `cat|catfish` will **never** match "catfish" — `cat` matches first.  
    Always put longer alternatives first: `catfish|cat`.

This only applies to NFA/backtracking engines. POSIX engines (DFA) always find the longest match regardless of order.

---

## Alternation vs. Character Classes

```regex
# Don't use alternation for single characters
(a|e|i|o|u)    # slow — each option is a separate NFA state
[aeiou]        # fast — direct lookup table in the engine

# Alternation is right for multi-char options
(?:Monday|Tuesday|Wednesday|Thursday|Friday)
```

---

## Grouping and Quantifiers

```regex
(?:foo|bar){2,4}        # alternation inside non-capturing group + quantifier
(?:https?|ftp)://       # alternation in URL scheme
^(?:error|warn|info):   # log level prefix
```

---

## Alternation Performance Tips

1. **Most-common first** — the first alternative that matches wins, so put the most frequent case first to avoid unnecessary tries.
2. **Single-char → character class** — `[aeiou]` instead of `a|e|i|o|u`.
3. **Non-overlapping** — `foo|foobar` vs `foobar|foo`. Overlapping alternatives cause wasted work.
4. **Factor common prefixes** — `(?:pre)?fix` instead of `fix|prefix`.
