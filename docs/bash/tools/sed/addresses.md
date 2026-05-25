# sed — Addressing Lines

An **address** tells sed *which lines* to apply a command to. Without an address, the command applies to every line.

---

## Address Forms

| Address Form | Matches |
|---|---|
| `N` | Line number N (1-based) |
| `$` | Last line |
| `0` | GNU: used as start of range with regex (`0,/re/` matches from start even if line 1 matches) |
| `/regex/` | Any line matching regex |
| `\cregexc` | Regex with delimiter `c` instead of `/` (useful when pattern contains `/`) |
| `first~step` | GNU: every `step`-th line starting at `first` (e.g., `1~2` = odd lines) |
| `addr1,addr2` | Range from `addr1` to `addr2` inclusive |
| `addr1,+N` | `addr1` and the next N lines |
| `addr1,~N` | GNU: `addr1` up to next multiple of N |
| `addr!` | Negate: apply to lines **NOT** matching addr |

---

## Examples

### Single line

```bash
# Apply only to line 3
sed '3s/foo/bar/' file

# Apply to the last line
sed '$s/foo/bar/' file
```

### Ranges

```bash
# Lines 5 through 10
sed '5,10s/foo/bar/' file

# From line matching /START/ to line matching /END/
sed '/START/,/END/s/foo/bar/' file

# From line 3 and the next 4 lines (lines 3-7)
sed '3,+4s/foo/bar/' file

# From first match to EOF (open range)
sed '/BEGIN/,$p' file
```

### Negation

```bash
# All lines EXCEPT line 1 (skip header)
sed '1!s/foo/bar/' file

# All lines NOT matching a pattern
sed '/^#/!s/foo/bar/' file
```

### GNU step addressing

```bash
# Odd lines: 1, 3, 5, ...
sed '1~2s/foo/bar/' file

# Even lines: 2, 4, 6, ...
sed '0~2s/foo/bar/' file

# Every 3rd line starting at line 2
sed '2~3s/foo/bar/' file
```

### Alternate regex delimiter

```bash
# Use | instead of / — handy when pattern contains /
sed '\|/usr/local|d' paths.txt
```

---

## Blocks: Multiple Commands on One Address

```bash
# Apply two commands only to lines with "ERROR"
sed '/ERROR/{
  s/ERROR/CRITICAL/
  s/$/ <<< ALERT/
}' logfile

# Same on one line with semicolons
sed '/ERROR/{s/ERROR/CRITICAL/;s/$/ <<< ALERT/}' logfile
```

---

!!! warning "Range Trap"
    A range `/START/,/END/` activates when the first regex matches and deactivates *after* the second matches. If **END never matches**, the range stays open until EOF. If START and END are on the same line, the range opens and then immediately closes at the next END match — which may be the same line.

!!! tip "0,/regex/ vs 1,/regex/"
    Use `0,/re/` (GNU) when you want the range to work even if the very first line matches the pattern. `1,/re/` would not close on line 1 because the end address is only tested starting from line 2.
