# awk — Patterns & Actions

Every awk rule has the form `pattern { action }`. The pattern controls *when* the action runs; the action controls *what* it does.

---

## Pattern Forms

| Pattern | Meaning |
|---------|---------|
| `BEGIN` | Execute before any input is read |
| `END` | Execute after all input is processed |
| `/regex/` | Lines where `$0` matches the regex |
| `!/regex/` | Lines where `$0` does NOT match |
| `$1 ~ /regex/` | Lines where field 1 matches regex |
| `$1 !~ /regex/` | Lines where field 1 does not match |
| `expression` | Any expression that evaluates to true (non-zero, non-empty) |
| `pat1, pat2` | Range: from first line matching `pat1` through first line matching `pat2` |
| `BEGINFILE` | gawk: runs at the start of each input file |
| `ENDFILE` | gawk: runs at the end of each input file |

---

## BEGIN and END

```awk
# Classic report structure
awk '
  BEGIN {
    print "=== Report ==="
    count = 0
  }
  /ERROR/ {
    count++
    print NR": "$0
  }
  END {
    print "---"
    print "Total errors:", count
  }
' logfile
```

Multiple `BEGIN` and `END` blocks are merged and run in script order:

```awk
awk '
  BEGIN { print "start 1" }
  BEGIN { print "start 2" }
  END   { print "end 1" }
  END   { print "end 2" }
' /dev/null
# Output:
# start 1
# start 2
# end 1
# end 2
```

---

## Regex Patterns

```awk
# Match whole line
awk '/ERROR/ { print }' logfile

# Negate
awk '!/^#/ { print }' config.txt    # skip comment lines

# Case-insensitive (gawk)
awk 'BEGIN{IGNORECASE=1} /error/ { print }' logfile

# Match a specific field
awk '$2 ~ /^[0-9]+$/ { print "numeric:", $2 }' file.txt

# Field does NOT match
awk '$1 !~ /test/ { print }' file.txt
```

---

## Expression Patterns

```awk
# Numeric comparison
awk '$3 > 1000 { print }' data.txt

# String comparison
awk '$2 == "ERROR" { print }' logfile

# Multiple conditions
awk '$3 > 100 && $4 == "active" { print }' data.txt

# OR condition
awk '$2 == "ERROR" || $2 == "WARN" { print }' log

# Line number
awk 'NR == 1 { print "Header:", $0 }' file.txt

# Skip header
awk 'NR > 1 { print }' file.txt

# Print only non-empty lines
awk 'NF > 0' file.txt
# or just:
awk 'NF' file.txt
```

---

## Range Patterns

```awk
# Print from /START/ to /END/ (inclusive)
awk '/START/,/END/ { print }' file.txt

# Equivalent with a flag variable (more explicit)
awk '
  /START/ { in_block = 1 }
  in_block { print }
  /END/   { in_block = 0 }
' file.txt

# Print lines between line 5 and line 10
awk 'NR==5, NR==10' file.txt

# Print lines between two timestamps
awk '/2024-01-15 09:00/, /2024-01-15 10:00/' app.log
```

!!! warning "Range Pattern Caveat"
    Like sed, once a range activates it stays active until the end pattern is found. If the end pattern never matches, the range runs to EOF.

---

## No-Pattern Rules

```awk
# No pattern = matches every record
awk '{ print NR, $0 }' file.txt

# Multiple rules apply to the same line
awk '
  /ERROR/ { errors++ }
  /WARN/  { warns++ }
           { total++ }   # always runs
  END      { print errors, warns, total }
' logfile
```

---

## BEGINFILE / ENDFILE (gawk)

```awk
# Per-file summary
awk '
  BEGINFILE {
    file_errors = 0
    print "=== Processing:", FILENAME
  }
  /ERROR/ { file_errors++ }
  ENDFILE {
    print FILENAME, "errors:", file_errors
  }
' *.log
```

---

## Patterns Without Actions

If you omit `{ action }`, the default action is `{ print }`:

```awk
awk '/ERROR/'  logfile     # same as awk '/ERROR/ { print }'
awk 'NF > 5'  file.txt    # print lines with more than 5 fields
awk '!seen[$0]++'  file   # deduplicate (print first occurrence of each line)
```
