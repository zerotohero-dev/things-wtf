# sed — Multi-line Operations

By default, sed processes one line at a time. The `N`, `P`, and `D` commands let you build a *multi-line pattern space* — enabling search and replace across line boundaries.

---

## The N/P/D Triad

| Command | Effect |
|---------|--------|
| `N` | Append the next input line to pattern space, separated by `\n` |
| `P` | Print only the **first** line of the (possibly multi-line) pattern space |
| `D` | Delete only the **first** line of pattern space, then **restart** the cycle without reading a new line |

---

## Sliding Two-Line Window

The canonical `N;P;D` loop creates a sliding window of two lines, allowing you to match or transform patterns that span a line boundary.

```bash
sed 'N; s/foo\nbar/REPLACEMENT/; P; D' file.txt
```

How it works:

1. `N` — read current + next line into pattern space (now has `\n` between them)
2. `s/foo\nbar/REPLACEMENT/` — try to match across the newline
3. `P` — print only the first line
4. `D` — delete the first line, restart cycle (re-execute script with the remaining line)

---

## Joining Lines

```bash
# Join every pair of lines with a space
sed 'N;s/\n/ /' file.txt

# Join lines ending with backslash (continuation lines)
sed -E ':a; /\\$/ { N; s/\\\n//; ba }' file.txt

# Join a line ending in comma with the next line
sed -E ':a; /,$/ { N; s/,\n/,/; ba }' file.txt
```

---

## Collapsing Blank Lines

```bash
# Reduce multiple consecutive blank lines to one
sed '/^$/{ N; /^\n$/d }' file.txt

# GNU: more concise
sed -E '/^\s*$/{2,d}' file.txt

# Remove ALL blank lines
sed '/^[[:space:]]*$/d' file.txt
```

---

## Deleting / Replacing Blocks

```bash
# Delete from /BEGIN/ to /END/ (inclusive)
sed '/BEGIN/,/END/d' file.txt

# Replace an entire block with a single line
sed '/BEGIN/,/END/c\[BLOCK REMOVED]' file.txt

# Delete the two lines surrounding a match
sed '/PATTERN/{N;d}' file.txt   # match + next line
sed -n 'h;/PATTERN/!{g;p};h' file.txt  # skip the line before match
```

---

## Multi-line Substitution

```bash
# Remove C-style block comments (single-line only, simplified)
sed 's|/\*[^*]*\*/||g' file.c

# Multi-line C block comment removal (loop)
sed -E ':a; s|/\*[^*]*\*/||g; ta; /\/\*/ { N; ba }' file.c

# Replace a two-line pattern
sed 'N; s/line one\nline two/MERGED/' file.txt
```

---

## Print Context Around a Match

```bash
# Print 2 lines after a match (using N twice)
sed -n '/PATTERN/{p;n;p;n;p}' file.txt

# Print the matched line and the one before it
sed -n '/PATTERN/{x;p;x;p};h' file.txt
```

---

!!! info "The N/P/D Loop Explained"
    `D` is the key to making the sliding window work. Unlike `d` (which starts the **next** cycle by reading the next input line), `D` restarts the **current** cycle with whatever remains in the pattern space — without discarding it and without reading a new line. This means the window slides forward by one line per iteration.
