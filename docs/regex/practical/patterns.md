# Common Patterns

Production-tested patterns with explanations. These are **pragmatic**, not mathematically perfect — most "perfect" validators (email, URL) are either thousands of characters long or should be delegated to a dedicated library.

---

## Email (Pragmatic)

```regex
# Catches 99% of real emails, rejects obvious nonsense
^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$

# More permissive (handles quoted local parts, + addressing)
^[^\s@]+@[^\s@]+\.[^\s@]+$
```

!!! info "Real-world advice"
    The only true email validator is to send a confirmation message. Use regex to reject obvious nonsense and let real attempts succeed.

---

## URL

```regex
# HTTP/HTTPS URL — permissive but covers most cases
https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&=]*)
```

For server-side validation, prefer the `URL` constructor:

```js
try { new URL(input); } catch(e) { /* invalid */ }
```

---

## IPv4 Address

```regex
^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$
```

Breakdown:

- `25[0-5]` → 250–255
- `2[0-4]\d` → 200–249
- `[01]?\d\d?` → 0–199

---

## ISO 8601 Date

```regex
^\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])$
```

> **Note:** Doesn't validate day-in-month (Feb 30 would pass). Do calendar validation in code after the regex.

---

## Time (HH:MM:SS)

```regex
^(?:[01]\d|2[0-3]):(?:[0-5]\d):(?:[0-5]\d)(?:\.\d+)?$
# Handles: 00:00:00 to 23:59:59, optional fractional seconds
```

---

## UUID v4

```regex
^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$
```

The `4` enforces version 4; `[89ab]` enforces the variant bits.

---

## Semantic Version

```regex
^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
```

Official semver.org pattern — handles pre-release (`-alpha.1`) and build metadata (`+build.123`).

---

## Phone Numbers (US)

```regex
^(?:\+1[-.\s]?)?\(?[2-9]\d{2}\)?[-.\s]?[2-9]\d{2}[-.\s]?\d{4}$
# Matches: (555) 867-5309, +1 555.867.5309, 5558675309
```

For international numbers, use `libphonenumber`.

---

## Credit Card (Basic)

```regex
^(?:4\d{12}(?:\d{3})?|5[1-5]\d{14}|3[47]\d{13}|6(?:011|5\d{2})\d{12})$
```

| Pattern | Card |
|---------|------|
| `4\d{12}(?:\d{3})?` | Visa (13 or 16 digits) |
| `5[1-5]\d{14}` | Mastercard |
| `3[47]\d{13}` | Amex |
| `6(?:011\|5\d{2})\d{12}` | Discover |

Always run a Luhn check alongside — regex only validates format, not checksum.

---

## Hex Color

```regex
^#(?:[0-9a-fA-F]{3}){1,2}$    # #RGB or #RRGGBB
^#(?:[0-9a-fA-F]{3,4}){1,2}$  # also #RGBA, #RRGGBBAA
```

---

## Slug / URL Segment

```regex
^[a-z0-9]+(?:-[a-z0-9]+)*$
```

Matches: `hello-world`, `my-post-2024` — no leading, trailing, or consecutive hyphens.

---

## Password Requirements

```regex
# Min 8 chars, at least: 1 uppercase, 1 digit, 1 special char
^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>?]).{8,}$
```

---

## JWT Token

```regex
^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$
# header.payload.signature — all base64url encoded segments
```

---

## Markdown Link Extraction

```regex
\[([^\]]+)\]\(([^)]+)\)
# group 1 = link text, group 2 = URL
```

---

## Log Line (Common Log Format)

```regex
^(\S+)\s\S+\s(\S+)\s\[([^\]]+)\]\s"(\S+)\s(\S+)\s\S+"\s(\d{3})\s(\d+|-)
# 1=host, 2=user, 3=timestamp, 4=method, 5=path, 6=status, 7=bytes
```

---

## Numbers

```regex
# Integer with optional sign
[+-]?\d+

# Float (incl. scientific notation)
[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?

# Currency (USD)
\$\d{1,3}(?:,\d{3})*(?:\.\d{2})?

# Binary
0[bB][01]+

# Hex
0[xX][0-9a-fA-F]+

# Octal
0[oO][0-7]+
```

---

## Git Commit Hash

```regex
^[0-9a-f]{7,40}$    # short (7+) or full (40) SHA-1
^[0-9a-f]{40}$      # full SHA-1 only
^[0-9a-f]{64}$      # SHA-256 (Git 2.x object names)
```

---

## CIDR Notation

```regex
^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\/(?:\d|[1-2]\d|3[0-2])$
# Validates IPv4 + prefix length 0-32
```
