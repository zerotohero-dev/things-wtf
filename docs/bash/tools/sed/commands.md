# sed — Core Commands

All sed commands beyond substitution. Every command can be prefixed with an [address](addresses.md).

---

## Command Reference

| Cmd | Name | Description |
|-----|------|-------------|
| `d` | delete | Delete pattern space; start next cycle (no print) |
| `p` | print | Print pattern space to stdout |
| `P` | Print | Print first line of multi-line pattern space |
| `q [N]` | quit | Print pattern space and exit with code N |
| `Q [N]` | Quit | Exit without printing (GNU extension) |
| `a text` | append | Append text after the current line |
| `i text` | insert | Insert text before the current line |
| `c text` | change | Replace matched line(s) with text |
| `=` | line number | Print current line number to stdout |
| `r file` | read | Append contents of file after current line |
| `R file` | Read | Read one line from file (GNU) |
| `w file` | write | Write pattern space to file |
| `W file` | Write | Write first line of pattern space to file (GNU) |
| `l` | list | Print pattern space unambiguously (shows `\n`, `\t`, etc.) |
| `y/src/dst/` | transliterate | Replace characters one-for-one (like `tr` but per-line) |
| `n` | next | Print pattern space, load next line into it |
| `N` | Next | Append next line to pattern space with embedded `\n` |
| `h` | hold | Copy pattern space → hold space |
| `H` | Hold | Append pattern space → hold space (with `\n`) |
| `g` | get | Copy hold space → pattern space |
| `G` | Get | Append hold space → pattern space (with `\n`) |
| `x` | exchange | Swap pattern space and hold space |
| `: label` | label | Define jump target for branch commands |
| `b [label]` | branch | Jump to label (or end of script if no label) |
| `t [label]` | test | Branch if any `s///` succeeded since last input or `t` |
| `T [label]` | Test | Branch if NO `s///` succeeded (GNU); opposite of `t` |
| `e [cmd]` | execute | Execute pattern space as shell command; replace with output (GNU) |
| `{ ... }` | block | Group multiple commands under one address |

---

## Deleting Lines

```bash
# Delete blank lines
sed '/^[[:space:]]*$/d' file.txt

# Delete lines containing "TODO"
sed '/TODO/d' source.go

# Delete the first line
sed '1d' file.txt

# Delete the last line
sed '$d' file.txt

# Delete lines 3 through 7
sed '3,7d' file.txt

# Delete lines from /BEGIN/ to EOF
sed '/BEGIN/,$d' file.txt

# Delete lines NOT matching a pattern (keep only matches)
sed '/ERROR/!d' logfile
# Equivalent to: grep ERROR logfile
```

---

## Printing Lines

```bash
# Print only lines 5 to 10 (suppress rest with -n)
sed -n '5,10p' file.txt

# Print only lines matching a pattern
sed -n '/ERROR/p' logfile

# Print first 5 lines then quit
sed '5q' file.txt

# Print line numbers alongside content
sed '=' file.txt | sed 'N;s/\n/\t/'
```

---

## Inserting and Appending Text

```bash
# Insert text BEFORE line 3
sed '3i\--- INSERTED LINE ---' file.txt

# Append text AFTER every line matching /SECTION/
sed '/SECTION/a\    # section ends here' file.txt

# GNU: more readable multiline syntax
sed '/pattern/a\
line one\
line two' file.txt

# Append a blank line after every line (double-space)
sed 'G' file.txt

# Insert a blank line before every line matching /HEADER/
sed '/HEADER/i\\' file.txt
```

---

## Changing Lines

```bash
# Replace lines 3 to 5 entirely with new text
sed '3,5c\[REDACTED]' file.txt

# Replace each line matching /OLD_VERSION/ with a new line
sed '/OLD_VERSION/c\NEW_VERSION: 2.0' file.txt

# Replace a range — the c command applies once to the whole range
sed '/START/,/END/c\[BLOCK REPLACED]' file.txt
```

---

## Transliteration

```bash
# Swap lowercase for uppercase (like tr a-z A-Z)
sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/' file

# Replace colons with tabs
sed 'y/:/\t/' file.txt

# ROT13
sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz/NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm/' file
```

!!! note "y vs s"
    `y` does character-for-character replacement across the whole line, like `tr`. It does not support regex — source and destination must have the same length.

---

## Read and Write Files

```bash
# Append the contents of header.txt after line 1
sed '1r header.txt' file.txt

# After each line matching /INJECT/, insert content of snippet.txt
sed '/INJECT/r snippet.txt' template.txt

# Write lines matching ERROR to a separate file
sed -n '/ERROR/w errors.txt' logfile

# Write and still print everything
sed '/ERROR/w errors.txt' logfile
```

---

## Quit Early

```bash
# Print the first 5 lines (faster than head for large files in pipelines)
sed '5q' bigfile.txt

# Print up to (and including) the first line matching a pattern
sed '/FOUND/q' file.txt

# GNU: quit without printing the matching line
sed '/FOUND/Q' file.txt
```

---

## Multiple Commands

```bash
# With -e flags
sed -e 's/foo/bar/' -e 's/baz/qux/' file.txt

# With semicolons (most implementations)
sed 's/foo/bar/;s/baz/qux/' file.txt

# With a block
sed '/ERROR/{
  s/ERROR/CRITICAL/
  s/$/ <<< ALERT/
  w /tmp/critical.log
}' logfile
```
