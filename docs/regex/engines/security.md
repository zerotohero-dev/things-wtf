# Security & ReDoS

**ReDoS** (Regular Expression Denial of Service) is a class of vulnerability where an attacker provides crafted input that triggers catastrophic backtracking, consuming 100% CPU and hanging the process.

---

## Attack Model

```
Target: server validating email addresses with a vulnerable regex
Pattern: (([a-zA-Z0-9])+\.?)+@
Attack string: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!"  (no @ sign)

Execution time grows exponentially with string length:
  Length 20 → ~1ms
  Length 30 → ~1s
  Length 40 → ~1000s (server hang)
```

The attacker just needs to send an HTTP request with a crafted header or form field and wait for the server to hang.

---

## Notable Real-World Incidents

| Date | Target | Impact |
|------|--------|--------|
| July 2019 | Cloudflare | Global outage ~27 minutes, 100% CPU on all WAF processes |
| 2016 | Stack Overflow | Server-side regex hang on crafted input |
| 2021 | npm `ua-parser-js` | User-agent parsing vulnerability |
| 2019 | `moment` JS library | Date parsing regex vulnerable to crafted strings |

---

## Defense Strategies

### 1. Audit Patterns

Review all regex patterns that process external input. Look for:

- Nested quantifiers: `(a+)+`, `(a*b+)+`
- Overlapping alternatives: `(\w|[a-z])+`
- Adjacent quantified groups that can match the same set

### 2. Use Linear-Time Engines

For any regex applied to untrusted input, consider:

- **Go's `regexp`** — RE2, guaranteed O(n)
- **Rust's `regex` crate** — RE2-based, O(n)
- **RE2 bindings** for Python (`google-re2`), Ruby, C++

### 3. Impose Timeouts

```python
# Python — regex module supports timeout
import regex
try:
    m = regex.match(pattern, input, timeout=0.5)  # 500ms limit
except regex.TimeoutError:
    # input caused excessive backtracking
    raise ValueError("input rejected")
```

```java
// Java — no built-in timeout, but can use ExecutorService
// Or use the re2j library (RE2 port to Java)
```

### 4. Bound Input Length

```js
if (input.length > 256) throw new Error("input too long");
// Then apply regex
```

For email: reject anything over 254 chars (RFC 5321 max) before even trying to validate.

### 5. Remove Nested Quantifiers from User-Facing Patterns

Apply the restructuring techniques from [Catastrophic Backtracking](backtracking.md) to every pattern that touches external data.

### 6. Never Compose Regex from Untrusted Input

```js
// NEVER DO THIS
const userPattern = req.body.pattern;
const re = new RegExp(userPattern);    // RCE + ReDoS risk
re.test(someString);
```

If you must allow user-supplied patterns:

- Use a sandbox/worker with a hard timeout and process isolation
- Pre-compile and static-analyze the pattern before use
- Restrict to RE2 syntax only

### 7. Escape User Input Used as Literals

```js
// JS — escape metacharacters from user input
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
const re = new RegExp(escapeRegex(userInput));
```

```python
import re
safe = re.escape(user_input)   # built-in
```

```java
String safe = Pattern.quote(userInput);   // wraps in \Q…\E
```

---

## Security Checklist

- [ ] All user-facing validation regex audited for nested quantifiers
- [ ] Input length bounded before applying regex
- [ ] Timeouts applied to regex operations on untrusted input, OR linear-time engine used
- [ ] No regex patterns constructed from user-supplied strings
- [ ] User-supplied literal strings escaped with `re.escape()` / `Pattern.quote()` / `escapeRegex()`
- [ ] Dependencies (`npm`, `pip`, `maven` packages) checked for known ReDoS CVEs
