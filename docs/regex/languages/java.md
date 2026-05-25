# Java / JVM

Java's `java.util.regex` package is a full-featured NFA engine supporting lookarounds, atomic groups, possessive quantifiers, and Unicode properties.

---

## Core API

```java
import java.util.regex.*;

// ── Compile — always cache as static final ────────────────────
private static final Pattern DATE_RE =
    Pattern.compile("(?<year>\\d{4})-(?<month>\\d{2})-(?<day>\\d{2})");

// ── Basic matching ────────────────────────────────────────────
Matcher m = DATE_RE.matcher("date: 2024-07-04");

// find() — scan string for next match
if (m.find()) {
    m.group(0);         // "2024-07-04" — full match
    m.group("year");    // "2024"
    m.group(1);         // "2024" — by index
    m.start();          // start position
    m.end();            // end position
}

// Loop all matches
while (m.find()) {
    System.out.println(m.group());
}

// matches() — ENTIRE string must match (implicit ^ and $)
Pattern.matches("\\d+", "123")    // true
Pattern.matches("\\d+", "123abc") // false — partial match fails

// ── Replace ───────────────────────────────────────────────────
// String convenience methods
"hello world".replaceAll("\\w+", "X")         // "X X"
"hello world".replaceFirst("\\w+", "X")       // "X world"

// Matcher — more control
m.reset();
String result = m.replaceAll("${year}/${month}/${day}");

// ── Split ─────────────────────────────────────────────────────
"a1b2c3".split("\\d")           // ["a", "b", "c", ""]
"a1b2c3".split("\\d", 2)        // ["a", "b2c3"] — limit=2
```

---

## Named Groups

```java
Pattern p = Pattern.compile("(?<year>\\d{4})-(?<month>\\d{2})");
Matcher m = p.matcher("2024-07");

if (m.matches()) {
    m.group("year");    // "2024"
    m.group("month");   // "07"
}

// Named group in replacement
m.reset();
m.find();
String result = m.replaceAll("${month}/${year}");  // "07/2024"
```

---

## Flags

```java
Pattern.compile("pattern", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE)

// Common flags
Pattern.CASE_INSENSITIVE    // (?i)
Pattern.MULTILINE           // (?m) — ^ and $ per line
Pattern.DOTALL              // (?s) — . matches \n
Pattern.COMMENTS            // (?x) — verbose mode
Pattern.UNICODE_CHARACTER_CLASS  // \w, \d, \b match Unicode
Pattern.UNICODE_CASE        // Unicode-aware case folding
```

---

## Possessive Quantifiers & Atomic Groups

Java supports both — use them for ReDoS prevention:

```java
// Possessive
Pattern.compile("\\d++[a-z]")       // digits possessively, then a letter

// Atomic group
Pattern.compile("(?>\\w+)\\s")    // word atomically, then whitespace
```

---

## Unicode

```java
// Basic Unicode properties
Pattern.compile("\\p{L}+")                    // any letter
Pattern.compile("\\p{Lu}+")                   // uppercase letters
Pattern.compile("\\p{InGreek}")               // Greek block
Pattern.compile("\\p{Sc}")                    // currency symbols

// Unicode-aware \w, \d, \s (requires flag)
Pattern.compile("\\w+", Pattern.UNICODE_CHARACTER_CLASS)
```

---

## Java-Specific Gotchas

!!! warning "Double-Backslash in Java Strings"
    Java string literals use `\` as escape character, so regex `\d` must be written as `"\\d"` in a Java string.  
    ```java
    Pattern.compile("\\d+")   // ✓ correct
    Pattern.compile("\d+")     // ✗ \d in Java string = backspace + 'd'
    ```

!!! warning "matches() vs find()"
    - `Matcher.matches()` — the **entire** string must match (anchored)
    - `Matcher.find()` — scans for the pattern anywhere in the string
    
    Confusing these two is the single most common Java regex bug.

!!! tip "Cache Pattern Objects"
    `Pattern.compile()` is expensive. Always declare patterns as `static final`:
    ```java
    private static final Pattern IP_RE =
        Pattern.compile("(\\d{1,3}\\.){3}\\d{1,3}");
    ```

---

## re2j — RE2 for Java

For ReDoS-safe matching with untrusted input, Google's `re2j` library provides RE2 semantics in Java:

```xml
<dependency>
    <groupId>com.google.re2j</groupId>
    <artifactId>re2j</artifactId>
    <version>1.7</version>
</dependency>
```

```java
import com.google.re2j.*;

Pattern p = Pattern.compile("\\d{4}-\\d{2}");
Matcher m = p.matcher("2024-07");
m.find();  // O(n) guaranteed
```
