# awk — I/O & Printf

awk can read from files and commands, write to multiple output files simultaneously, pipe to shell commands, and format output precisely with `printf`.

---

## print vs printf

| | `print` | `printf` |
|-|---------|---------|
| Newline | Appended automatically (`ORS`) | Not added — you must include `\n` |
| Arguments | Separated by `OFS` | Formatted by format string |
| Use case | Quick output | Aligned, formatted output |

```awk
# print: auto-separates with OFS, ends with ORS
awk '{ print $1, $2, $3 }' file.txt

# printf: full control
awk '{ printf "%-20s %8.2f %s\n", $1, $2, $3 }' file.txt
```

---

## printf Format Specifiers

| Specifier | Meaning |
|-----------|---------|
| `%d`, `%i` | Integer |
| `%f` | Floating point (`3.140000`) |
| `%e`, `%E` | Scientific notation |
| `%g`, `%G` | Shorter of `%f` or `%e` |
| `%s` | String |
| `%c` | Single character (or ASCII code) |
| `%o` | Octal |
| `%x`, `%X` | Hexadecimal |
| `%%` | Literal `%` |

**Width and precision modifiers:**

| Modifier | Example | Effect |
|----------|---------|--------|
| Width | `%10s` | Right-align in 10-char field |
| Left-align | `%-10s` | Left-align in 10-char field |
| Zero-pad | `%010d` | Zero-pad integer to 10 digits |
| Precision | `%.3f` | 3 decimal places |
| Both | `%10.2f` | 10 wide, 2 decimals |
| Sign | `%+d` | Always show `+` or `-` |

```awk
# Column-aligned report
awk 'BEGIN {
  printf "%-20s %10s %8s\n", "NAME", "SIZE", "STATUS"
  printf "%-20s %10s %8s\n", "----", "----", "------"
}
{ printf "%-20s %10d %8s\n", $1, $2, $3 }' data.txt

# Hex dump of first field
awk '{ printf "%s = 0x%X\n", $1, $1 + 0 }' nums.txt
```

---

## Redirecting Output

```awk
# Write to a file (creates/overwrites)
awk '{ print > "output.txt" }' file.txt

# Append to a file
awk '{ print >> "output.txt" }' file.txt

# Write to different files based on content
awk '{
  if ($3 == "ERROR") print > "errors.txt"
  else               print > "ok.txt"
}' logfile

# Closing files explicitly (flushes, allows reuse later)
awk '/SECTION/ {
  close(outfile)
  outfile = "section_" NR ".txt"
}
{ print > outfile }' file.txt
```

!!! warning "File handles"
    awk keeps file handles open for the lifetime of the program. If you're writing to many different files (e.g., one per key), explicitly `close(filename)` when done with each one to avoid hitting the OS file descriptor limit.

---

## Piping Output

```awk
# Pipe all output to sort
awk '{ print $0 | "sort -k2" }' file.txt

# Pipe to different commands based on content
awk '{
  if ($3 > 1000) print | "mail -s alert admin@example.com"
  else           print | "tee -a normal.log"
}' data.txt

# Always close pipes you reuse
awk '{
  print $0 | "sort"
}
END {
  close("sort")
}' file.txt
```

---

## Writing to stderr

```awk
awk '{
  print "Error on line " NR > "/dev/stderr"
}' file.txt

# Or pipe to cat >&2
awk '{ print "warn:" NR | "cat >&2" }' file.txt
```

---

## getline

`getline` reads the next record from input (or a file/command) into the specified variable (or `$0` if omitted).

Return values: `1` = success, `0` = EOF, `-1` = error.

```awk
# Read next line from stdin into $0 (advances the main loop)
awk '{ getline; print }' file.txt   # prints every other line

# Read next line into a variable (does not change $0 or fields)
awk '{ getline nextline; print $0, "->", nextline }' file.txt

# Read from a file
awk '{
  while ((getline line < "/etc/hosts") > 0)
    print line
  close("/etc/hosts")
}'

# Read from a command
awk '{
  cmd = "date +%s"
  cmd | getline timestamp
  close(cmd)
  print timestamp, $0
}' file.txt

# Check getline return value
awk '{
  ret = (getline line < "data.txt")
  if (ret > 0) print "got:", line
  else if (ret == 0) print "EOF"
  else print "error"
}' /dev/null
```

!!! warning "getline gotchas"
    Using bare `getline` (without `< file` or `| cmd`) reads from the **main input stream**, which advances the main loop's position. This can cause records to be silently skipped. Prefer `getline var < file` or `cmd | getline var` for predictability.

---

## Reading All Lines into an Array

```awk
awk '{ lines[NR] = $0 }
END {
  # Now process lines[] in any order
  for (i=NR; i>=1; i--) print lines[i]   # reverse
}' file.txt
```

---

## Two-pass Processing Without Temp Files

```awk
# Process the same input twice using ARGV manipulation
awk '
  BEGINFILE { pass++ }
  pass==1   { total += $3 }
  pass==2   { printf "%.1f%%\n", $3/total*100 }
' file.txt file.txt   # pass the file twice on command line
```
