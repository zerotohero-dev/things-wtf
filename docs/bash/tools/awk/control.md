# awk — Control Flow

awk supports the full C-style control flow: `if/else`, `while`, `do-while`, `for`, `for-in`, plus `next`, `nextfile`, `exit`, `break`, and `continue`.

---

## if / else

```awk
awk '{
  if ($3 > 500) {
    print "HIGH:", $0
  } else if ($3 > 100) {
    print "MED:", $0
  } else {
    print "LOW:", $0
  }
}' data.txt

# Ternary operator
awk '{ status = ($3 > 0) ? "positive" : "zero or negative"; print status }' data.txt

# Ternary in print
awk '{ print $1, ($2 > 50 ? "pass" : "fail") }' scores.txt
```

---

## while Loop

```awk
awk '{
  i = 1
  while (i <= NF) {
    printf "[%s]", $i
    i++
  }
  print ""
}' file.txt
```

---

## do-while Loop

```awk
awk 'BEGIN {
  i = 1
  do {
    print i
    i++
  } while (i <= 5)
}'
```

---

## for Loop (C-style)

```awk
# Print fields in reverse order
awk '{
  for (i = NF; i >= 1; i--)
    printf "%s%s", $i, (i > 1 ? " " : "\n")
}' file.txt

# Sum all fields on a line
awk '{
  s = 0
  for (i = 1; i <= NF; i++) s += $i
  print s
}' numbers.txt
```

---

## for-in Loop (Arrays)

```awk
# Iterate an array (order is undefined)
awk '{
  count[$1]++
}
END {
  for (key in count)
    print key, count[key]
}' file.txt

# Sort the keys first (gawk)
awk '{count[$1]++}
END {
  n = asorti(count, sorted_keys)
  for (i=1; i<=n; i++)
    print sorted_keys[i], count[sorted_keys[i]]
}' file.txt
```

---

## next

`next` skips the remaining rules for the current record and jumps to the next input line. Like `continue` for the main record loop.

```awk
# Skip comment lines
awk '/^#/ { next } { print }' config.txt

# Skip blank lines
awk '!NF { next } { print NR, $0 }' file.txt

# Skip header, process the rest
awk 'NR==1 { next } { total += $3 } END { print total }' data.csv
```

---

## nextfile (gawk)

`nextfile` skips the rest of the current input file and jumps to the next one.

```awk
# Find which files contain an error (stop at first match per file)
awk '
  /ERROR/ { print FILENAME; nextfile }
' *.log

# Count files that have no errors
awk '
  BEGINFILE { has_error=0 }
  /ERROR/   { has_error=1; nextfile }
  ENDFILE   { if (!has_error) clean++ }
  END       { print clean, "clean files" }
' *.log
```

---

## exit

`exit` stops processing input and jumps directly to the `END` block (if any).

```awk
# Stop after line 100 (much faster than processing the whole file)
awk 'NR == 100 { exit } { print }' bigfile.txt

# Find first match and exit
awk '/PATTERN/ { print; exit }' file.txt

# exit with a code (accessible in shell as $?)
awk '/PATTERN/ { found=1; exit } END { exit !found }' file.txt
```

---

## break and continue

```awk
awk '{
  for (i = 1; i <= NF; i++) {
    if ($i == "skip") continue   # skip this iteration
    if ($i == "stop") break      # exit the loop
    print $i
  }
}'

# continue in while
awk 'BEGIN {
  i = 0
  while (i < 10) {
    i++
    if (i % 2 == 0) continue   # skip even numbers
    print i
  }
}'
```

---

## Operator Precedence

From highest to lowest:

| Operators | Notes |
|-----------|-------|
| `( )` | Grouping |
| `$` | Field reference |
| `^` or `**` | Exponentiation (right-associative) |
| `! + -` | Unary |
| `* / %` | Multiplication, division, modulo |
| `+ -` | Addition, subtraction |
| `" "` | String concatenation (adjacent strings) |
| `< <= > >= == !=` | Comparison |
| `~ !~` | Regex match / non-match |
| `in` | Array membership |
| `&&` | Logical AND |
| `\|\|` | Logical OR |
| `? :` | Ternary |
| `= += -= *= /= %= ^=` | Assignment |

---

!!! tip "next vs exit"
    `next` moves to the next input record (stays inside the main loop). `exit` jumps to `END` and terminates. Use `next` to skip a record, `exit` to stop the whole program early.
