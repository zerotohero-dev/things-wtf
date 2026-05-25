# Atomic Groups & Possessive Quantifiers

These are the most powerful tools to prevent catastrophic backtracking. They tell the engine: **"once you've matched this, never give it back, no matter what."**

---

## Possessive Quantifiers

Syntax: `*+`, `++`, `?+`, `{n,m}+`

**Supported in:** PCRE, Java, Ruby  
**Not available in:** JavaScript, Python's `re` (Python's `regex` module supports them)

```regex
\d++          # match digits possessively — won't give them back
[a-z]++        # possessive on a character class
(?:ab)++       # possessive on a group
```

The engine matches as much as possible, then **discards all backtrack positions** — it cannot give anything back.

```
Pattern: \d++X
Input:   "123"

Step 1: \d++ consumes "123" possessively
Step 2: Try to match 'X' — fail
Step 3: Cannot backtrack (possessive) → overall fail immediately

vs. greedy \d+X on "123":
Step 1: \d+ consumes "123"
Step 2: Try 'X' — fail
Step 3: Backtrack → \d+ gives back '3', now "12"
Step 4: Try 'X' at '3' — fail
Step 5: Backtrack again... (explores O(n) paths before failing)
```

---

## Atomic Groups

Syntax: `(?>…)`

**Supported in:** PCRE, Java, .NET, Ruby  
**Not available in:** JavaScript, Python `re`

Once the group matches and the engine exits it, all alternative positions *within* the group are discarded:

```regex
# Classic catastrophic pattern
(a+)+b     # catastrophic on "aaaa...X" — exponential backtracking

# Fixed with atomic group
(?>a+)+b   # PCRE/Java — inner a+ matches, no internal backtrack possible

# Possessive equivalent (cleaner)
a++b       # same effect, simpler syntax
```

---

## Real Use Cases

```regex
# URL scheme — once we match "https", don't backtrack into it
(?:https?|ftp)://    # non-possessive (fine for short alts)
(?>https?|ftp)://    # atomic — marginally faster, intent is clear

# Identifier lexer — word chars form a complete token
\b(?>\w+)          # match a full word atomically

# Number with no backtrack into digits
(?>\d+)\.?\d*     # digits are committed
```

---

## JavaScript Workaround

JavaScript has no atomic groups or possessive quantifiers. Options:

1. **Restructure** to eliminate the ambiguity:
   ```js
   // Instead of (a+)+, which is catastrophic:
   a+    // if outer repetition is unnecessary, remove it
   ```

2. **Use a negated class** to prevent overlap:
   ```js
   (?:[^"]*")+    // no atomic needed — [^"]* can't overlap with "
   ```

3. **Input length validation** before applying the regex

4. **Switch to RE2** (via the `re2` npm package) for guaranteed linear time

---

## When to Use

- When a group can only match in one way (no ambiguity inside) — make it atomic
- When processing untrusted input — possessive/atomic groups harden against ReDoS
- When you know a token is complete (e.g., once you matched `https`, don't reconsider)
- In any pattern that has nested quantifiers and will run on variable-length input
