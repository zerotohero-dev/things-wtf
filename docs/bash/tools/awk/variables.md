# awk — Built-in Variables

awk's built-in variables control how input is split, how output is joined, and expose metadata about the current state of processing.

---

## Complete Reference

| Variable | Default | Purpose |
|----------|---------|---------|
| `FS` | `" "` | Input field separator. `" "` (space) = split on runs of whitespace (special). Any other value splits literally. |
| `OFS` | `" "` | Output field separator. Used when printing multiple args with `print $1, $2` or when awk reconstructs `$0` after field assignment. |
| `RS` | `"\n"` | Input record separator. Set to `""` for paragraph mode. gawk: can be a regex. |
| `ORS` | `"\n"` | Output record separator. Appended after each `print` statement. |
| `NR` | — | Total number of records read so far (cumulative across files). |
| `NF` | — | Number of fields in the current record. |
| `FNR` | — | Record number within the current file only (resets to 1 at each new file). |
| `FILENAME` | — | Name of the current input file. |
| `ARGC` | — | Number of command-line arguments (including `awk` itself). |
| `ARGV` | — | Array of command-line arguments: `ARGV[0]` = "awk". |
| `ENVIRON` | — | Array of environment variables: `ENVIRON["HOME"]`. gawk. |
| `OFMT` | `"%.6g"` | Format used when converting numbers to strings for output. |
| `CONVFMT` | `"%.6g"` | Format used when converting numbers to strings internally. |
| `SUBSEP` | `"\034"` | Separator for multi-dimensional array subscripts (used in `arr[a,b]`). |
| `FIELDWIDTHS` | — | gawk: space-separated field widths for fixed-width input. |
| `FPAT` | — | gawk: regex describing what a field *looks like* (vs what separates fields). |
| `IGNORECASE` | `0` | gawk: set to 1 for case-insensitive regex and string comparisons. |
| `PROCINFO` | — | gawk: array with process info (`PROCINFO["pid"]`, `PROCINFO["version"]`, etc.). |
| `RT` | — | gawk: the text that matched `RS` (the actual record terminator). |

---

## FS and OFS

```awk
# Set both FS and OFS in BEGIN
awk 'BEGIN{FS=":"; OFS="\t"} {print $1, $3}' /etc/passwd

# Changing OFS affects how $0 is reconstructed
awk 'BEGIN{FS=","; OFS="|"} {$1=$1; print}' data.csv
# $1=$1 forces awk to rebuild $0 with the new OFS

# Multi-character FS
awk -F' :: ' '{print $1}' structured.log

# Regex FS
awk -F'[,;|]+' '{print NF, $0}' mixed.txt
```

---

## RS and Paragraph Mode

```awk
# Paragraph mode: treat blank lines as record separators
# Each "record" is a paragraph; fields within are newline-separated
awk 'BEGIN{RS=""; FS="\n"} { print NR": first line is "$1 }' doc.txt

# Custom record separator
awk 'BEGIN{RS="---\n"} { print NR, NF }' frontmatter.md

# gawk: regex RS
awk 'BEGIN{RS="[0-9]+ "} { print NR": "$0 }' file.txt

# ORS: change line ending in output
awk 'BEGIN{ORS=","} {print $1}' file.txt | sed 's/,$/\n/'
# Prints all $1 values on one line separated by commas
```

---

## ENVIRON

```awk
# Access environment variables
awk 'BEGIN {
  print ENVIRON["HOME"]
  print ENVIRON["PATH"]
  if ("DEBUG" in ENVIRON) print "debug mode on"
}'

# Pass a shell variable into awk via -v (preferred over ENVIRON for single values)
awk -v threshold="$THRESHOLD" '$3 > threshold' data.txt
```

---

## FPAT: Field-by-pattern (proper CSV)

Standard `FS=","` breaks on commas inside quoted fields. `FPAT` describes what a *field looks like* instead.

```awk
# Handle CSV with quoted fields containing commas
awk 'BEGIN {
  FPAT = "([^,]*)|(\"[^\"]*\")"
} {
  print $2   # second field, even if it contains commas
}' data.csv
```

---

## FIELDWIDTHS: Fixed-width input

```awk
# Fixed-width fields: col 1-10, col 11-18, col 19-30
awk 'BEGIN{FIELDWIDTHS="10 8 12"} {print $1, $3}' fixed.txt
```

---

## IGNORECASE

```awk
# Case-insensitive matching (gawk)
awk 'BEGIN{IGNORECASE=1} /error/ {print}' logfile

# Case-insensitive comparison
awk 'BEGIN{IGNORECASE=1} $1 == "error" {print}' logfile
```

---

## Setting Variables with -v

```awk
# Pass variables from the shell
awk -v min=100 -v max=500 '$3 >= min && $3 <= max' data.txt

# Multiple -v flags
awk -v OFS='\t' -v threshold=50 '$2 > threshold {print $1, $2}' data.txt

# -v evaluated before BEGIN
awk -v x=5 'BEGIN{print x+1}'
```

!!! tip "When to use -v vs ENVIRON"
    Use `-v var=val` for single values you're passing in. Use `ENVIRON` when you want access to the full environment, or when the value may be a complex string (the `-v` flag interprets escape sequences, which can corrupt binary data or paths with backslashes).
