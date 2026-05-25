# awk — String Functions

awk has a rich set of built-in string functions. The gawk-specific ones (`gensub`, `patsplit`, `match` with capture groups) are marked.

---

## Function Reference

| Function | Description |
|----------|-------------|
| `length(s)` | Length of string `s`. Omit argument for `length($0)`. |
| `substr(s, start [, len])` | Substring of `s` starting at `start` (1-indexed), optional max length `len`. |
| `index(s, t)` | Position of `t` in `s`, or 0 if not found. |
| `split(s, a [, fs [, seps]])` | Split `s` into array `a` using `fs`. Returns element count. gawk: `seps` captures separators. |
| `sub(r, s [, t])` | Replace **first** match of regex `r` with `s` in `t` (default `$0`). Returns number of replacements. |
| `gsub(r, s [, t])` | Replace **all** matches of regex `r` with `s` in `t`. Returns count. |
| `gensub(r, s, how [, t])` | gawk: like `gsub` but returns new string without modifying `t`. `how`=`"g"` for all, or `"1"`, `"2"`… for Nth. |
| `match(s, r [, a])` | Find `r` in `s`. Sets `RSTART` and `RLENGTH`. gawk: array `a` captures groups. Returns RSTART. |
| `sprintf(fmt, ...)` | Format a string (like `printf` but returns the string). |
| `toupper(s)` | Convert `s` to uppercase. |
| `tolower(s)` | Convert `s` to lowercase. |
| `patsplit(s, a, r [, seps])` | gawk: split `s` by matches of regex `r` into array `a`. |
| `strtonum(s)` | gawk: convert string to number. Handles hex (`0x…`) and octal (`0…`). |

---

## substr

```awk
# Characters 5 through 10 (start=5, length=6)
awk '{ print substr($0, 5, 6) }' file.txt

# From position 5 to end of string
awk '{ print substr($0, 5) }' file.txt

# Last 4 characters
awk '{ print substr($0, length($0)-3) }' file.txt

# Extract filename from path
awk -F'/' '{ print $NF }' paths.txt
# or using substr + index:
awk '{
  n = split($0, parts, "/")
  print parts[n]
}' paths.txt
```

---

## index

```awk
# Find position of a substring
awk '{ pos = index($0, "ERROR"); if (pos) print pos, $0 }' log

# Check if a field contains a substring
awk '{ if (index($2, "test") > 0) print }' file.txt
```

---

## split

```awk
# Split a field by a delimiter
awk -F':' '{
  n = split($5, parts, " ")
  for (i=1; i<=n; i++) print parts[i]
}' /etc/passwd

# Split and count
awk '{ n = split($0, a, ","); print n, "fields" }' data.csv

# Split with regex delimiter
awk '{
  n = split($0, parts, /[[:space:]]+/)
  print n, parts[1]
}' file.txt

# gawk: capture separators too
awk '{
  n = split($0, fields, /,/, seps)
  for (i=1; i<=n; i++) printf "[%s]%s", fields[i], seps[i]
  print ""
}' data.csv
```

---

## sub and gsub

```awk
# Replace first occurrence (modifies $0 in-place)
awk '{ sub(/foo/, "bar"); print }' file.txt

# Replace all occurrences
awk '{ gsub(/[[:space:]]+/, "_"); print }' file.txt

# Replace in a specific field
awk '{ gsub(/,/, ";", $3); print }' data.txt

# Use & to reference the matched text
awk '{ gsub(/[0-9]+/, "(&)"); print }' file.txt

# Count replacements (gsub returns the number made)
awk '{ n = gsub(/foo/, "bar"); if (n > 0) print n, "replacements:", $0 }' file.txt

# Escape & and \ in replacement
# & means "matched text" in replacement — to use a literal &, escape it: \&
awk '{ gsub(/foo/, "a\\&b"); print }' file.txt   # replaces "foo" with "a&b"
```

---

## gensub (gawk)

Unlike `sub`/`gsub`, `gensub` returns a new string and leaves the original unchanged.

```awk
# Replace all, return new string
awk '{ result = gensub(/foo/, "bar", "g"); print result }' file.txt

# Replace only the 2nd occurrence
awk '{ print gensub(/foo/, "bar", 2) }' file.txt

# Use capture group backreference (\1, \2, ...)
awk '{ print gensub(/([0-9]+)/, "NUM(\\1)", "g") }' file.txt

# Wrap each word in brackets
awk '{ print gensub(/([a-zA-Z]+)/, "[\\1]", "g") }' file.txt

# Swap two fields
awk -F: '{ print gensub(/^([^:]+):([^:]+)/, "\\2:\\1", 1) }' file.txt
```

---

## match

```awk
# Find a pattern; RSTART and RLENGTH are set
awk '{
  if (match($0, /[0-9]+\.[0-9]+/)) {
    print "Found at:", RSTART, "length:", RLENGTH
    print "Match:", substr($0, RSTART, RLENGTH)
  }
}' file.txt

# gawk: capture groups into array
awk '{
  if (match($0, /v([0-9]+)\.([0-9]+)\.([0-9]+)/, m)) {
    print "major:", m[1], "minor:", m[2], "patch:", m[3]
  }
}' versions.txt

# Extract all matches (loop with substr)
awk '{
  s = $0
  while (match(s, /[0-9]+/)) {
    print substr(s, RSTART, RLENGTH)
    s = substr(s, RSTART + RLENGTH)
  }
}' file.txt
```

---

## sprintf

```awk
# Format without printing
awk '{ tag = sprintf("<%s>", $1); print tag $2 "</>" }' file.txt

# Zero-pad numbers
awk '{ id = sprintf("%05d", $1); print id }' ids.txt

# Build a formatted line for later use
awk '{
  line = sprintf("%-20s %8.2f %s", $1, $2, $3)
  print line
}' data.txt
```

---

## Case Conversion

```awk
# Uppercase a field
awk '{ $2 = toupper($2); print }' file.txt

# Lowercase everything
awk '{ print tolower($0) }' file.txt

# Title case (capitalize first letter of each word — gawk gensub)
awk '{
  print gensub(/\b(.)/, "\\u\\1", "g")   # \u = uppercase next char (gawk extension)
}' file.txt
```

---

## String Concatenation

awk concatenates strings by simple juxtaposition — no operator needed:

```awk
awk '{ result = $1 "-" $2 "-" $3; print result }' file.txt

awk '{ print "Hello, " $1 "!" }' names.txt

# Build a comma-separated list
awk '{
  line = ""
  for (i=1; i<=NF; i++) {
    line = line (i>1 ? "," : "") $i
  }
  print line
}' file.txt
```

---

## Trim Whitespace

awk has no built-in trim function:

```awk
# Trim leading and trailing whitespace from $0
awk '{ gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }' file.txt

# Trim a specific field
awk '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print }' file.txt

# Define a trim function (see user functions page)
awk '
function trim(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}
{ print trim($0) }
' file.txt
```
