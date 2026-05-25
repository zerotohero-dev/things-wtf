# sed — Pattern Space & Hold Space

sed has two internal string buffers. Mastering them unlocks techniques impossible with simple substitution.

---

## The Two Buffers

```
┌─────────────────────────────────────────────────────────────┐
│  PATTERN SPACE                                              │
│  • Holds the current line being processed                   │
│  • Gets cleared at the start of each cycle                  │
│  • Is printed (unless -n) at the end of each cycle          │
│  • Commands like s, d, p operate directly on it             │
├─────────────────────────────────────────────────────────────┤
│  HOLD SPACE                                                 │
│  • A scratch buffer that persists across all cycles         │
│  • Starts as a single empty string                          │
│  • Never automatically cleared or printed                   │
│  • Only changed by h, H, g, G, x                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Buffer Commands

| Command | Effect |
|---------|--------|
| `h` | Copy pattern space → hold space (overwrites hold) |
| `H` | Append pattern space → hold space (with `\n` separator) |
| `g` | Copy hold space → pattern space (overwrites pattern) |
| `G` | Append hold space → pattern space (with `\n` separator) |
| `x` | Swap pattern space and hold space |

---

## Classic Idioms

### Reverse line order (`tac` equivalent)

```bash
sed -n '1!G;h;$p' file.txt
```

Step by step:

| Command | Meaning |
|---------|---------|
| `1!G` | For all lines except line 1, append hold space to pattern space |
| `h` | Copy the (now combined) pattern space back to hold space |
| `$p` | On the last line, print the accumulated hold space |

After each cycle, hold space grows: it becomes `lineN \n lineN-1 \n ... \n line1`, and we print that at the end.

---

### Print the line BEFORE a match

```bash
sed -n '/PATTERN/{x;p;x};h' file.txt
```

- `h` saves the current line to hold space every cycle.
- On a match: `x` brings the *previous* line into pattern space, `p` prints it, `x` restores.

---

### Print the line AFTER a match

```bash
sed -n '/PATTERN/{n;p}' file.txt
```

`n` moves to the next line, then `p` prints it.

---

### Delete the line after a match

```bash
sed '/PATTERN/{n;d}' file.txt
```

---

### Insert a blank line after every line

```bash
sed 'G' file.txt
```

Hold space starts empty, so appending it adds a `\n` (blank line) after each line.

---

### Remove blank lines added by double-spacing

```bash
sed -n 'p;n' file.txt
```

---

### Join every pair of lines

```bash
sed 'N;s/\n/ /' file.txt
```

`N` appends the next line (with `\n`), then `s` replaces the newline with a space.

---

### Swap two adjacent lines

```bash
sed -n 'h;n;p;g;p' file.txt
# h: save line1 to hold
# n: read line2 into pattern
# p: print line2
# g: get line1 back
# p: print line1
```

---

### Accumulate all lines, then process in END-like block

```bash
# Print line count using hold space
sed -n 'H;${g;s/\n/\n/g;=}' file.txt
```

For this kind of "process everything at once" work, `awk` is usually cleaner.

---

!!! tip "Mental Model"
    Think of pattern space as a whiteboard that gets erased every cycle, and hold space as a notepad you keep on the desk. `h/H/g/G/x` are the only ways to move data between them.
