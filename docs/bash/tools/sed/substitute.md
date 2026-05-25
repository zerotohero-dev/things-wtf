# sed — Substitution (s command)

The `s` command is the workhorse of sed. It replaces the first (or all) occurrences of a regex in the pattern space.

---

## Syntax

```
s/REGEX/REPLACEMENT/[FLAGS]
```

The delimiter `/` can be any character — use `|`, `#`, or `@` when the pattern contains slashes.

---

## Flags

| Flag | Effect |
|------|--------|
| `g` | Replace **all** occurrences on the line (not just the first) |
| `N` (number) | Replace only the N-th occurrence |
| `p` | Print the line if substitution was made (useful with `-n`) |
| `i` / `I` | Case-insensitive match (GNU sed) |
| `e` | After substitution, execute the pattern space as a shell command (GNU) |
| `m` / `M` | Multi-line mode: `^` and `$` match start/end of each line in pattern space |
| `w file` | Write lines where substitution occurred to `file` |

---

## Replacement Tokens

| Token | Meaning |
|-------|---------|
| `&` | The entire matched string |
| `\1` … `\9` | Capture group backreference |
| `\u` | Uppercase next character (GNU) |
| `\l` | Lowercase next character (GNU) |
| `\U` | Uppercase everything until `\E` or end (GNU) |
| `\L` | Lowercase everything until `\E` or end (GNU) |
| `\E` | End `\U` or `\L` transformation (GNU) |
| `\n` | Newline in replacement |

---

## Basic Substitution

```bash
# Replace first occurrence
sed 's/localhost/127.0.0.1/' nginx.conf

# Replace all occurrences on each line
sed 's/foo/bar/g' file.txt

# Replace only the 2nd occurrence per line
sed 's/foo/bar/2' file.txt

# Replace the 2nd and all subsequent occurrences (GNU: combine N and g)
sed 's/foo/bar/2g' file.txt

# Case-insensitive global replace (GNU)
sed 's/error/ERROR/Ig' logfile
```

---

## Using & (whole match)

```bash
# Wrap every number in brackets
sed 's/[0-9]\+/[&]/g' file.txt

# Quote every word
sed 's/[a-zA-Z]\+/"&"/g' file.txt

# Add parentheses around an IP address
sed 's/[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}/(&)/' file.txt
```

---

## Capture Groups

```bash
# Swap first two colon-delimited fields (BRE)
sed 's/\([^:]*\):\([^:]*\)/\2:\1/' /etc/passwd

# Same with ERE (-E) — more readable
sed -E 's/([^:]+):([^:]+)/\2:\1/' /etc/passwd

# Extract just the filename from a path
sed -E 's|.*/([^/]+)$|\1|' paths.txt

# Reformat date from YYYY-MM-DD to DD/MM/YYYY
sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/' dates.txt
```

---

## Case Conversion (GNU)

```bash
# Uppercase the entire line
sed 's/.*/\U&/' file.txt

# Lowercase the entire line
sed 's/.*/\L&/' file.txt

# Title-case: uppercase first letter of each word
sed 's/\b\w/\u&/g' file.txt

# Uppercase only the first word
sed 's/^\w\+/\u&/' file.txt

# Uppercase a specific capture group
sed -E 's/(error|warn)/\U\1\E/gi' logfile
```

---

## Alternate Delimiters

```bash
# Replace paths — avoid escaping slashes
sed 's|/usr/local|/opt|g' Makefile

# Using # as delimiter
sed 's#http://old.host#https://new.host#g' urls.txt

# Using @ as delimiter
sed 's@pattern@replacement@g' file
```

---

## Practical Substitutions

```bash
# Delete trailing whitespace
sed 's/[[:space:]]*$//' file.txt

# Delete leading whitespace
sed 's/^[[:space:]]*//' file.txt

# Remove HTML tags
sed -E 's/<[^>]+>//g' file.html

# Add prefix to every line
sed 's/^/PREFIX: /' file.txt

# Add suffix to every line
sed 's/$/ SUFFIX/' file.txt

# Normalize Windows CRLF to LF
sed 's/\r//' windows.txt

# Collapse multiple spaces into one
sed 's/  */ /g' file.txt

# Remove blank lines
sed '/^[[:space:]]*$/d' file.txt

# Double-quote the third field (colon-delimited)
sed -E 's/^([^:]*:[^:]*:)([^:]*)/\1"\2"/' file
```

---

## Print Only Changed Lines

```bash
# With -n and /p flag: only output lines where substitution occurred
sed -n 's/ERROR/FOUND: &/p' logfile

# Useful for extracting matching lines with transformation
sed -n 's/.*version: "\([^"]*\)".*/\1/p' Chart.yaml
```

---

## Execute Replacement as Shell Command (GNU)

```bash
# /e flag: execute the resulting pattern space as a shell command
# Bump semver patch number using shell arithmetic
sed -E 's/(version: "[0-9]+\.[0-9]+\.)([0-9]+)(")/echo "\1$((\2+1))\3"/e' Chart.yaml

# Resolve a symlink inline
sed 's/.*/readlink -f &/e' symlinks.txt
```

!!! warning "Security"
    The `/e` flag passes the pattern space to the shell. Never use it on untrusted input.
