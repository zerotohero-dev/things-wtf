# awk — Fields & Records

awk's defining feature: it automatically splits each input record into numbered fields.

---

## Field References

| Reference | Meaning |
|-----------|---------|
| `$0` | The entire current record (line) |
| `$1`, `$2`, `$N` | Field N (1-indexed) |
| `$NF` | Last field (`NF` is the number of fields) |
| `$(NF-1)` | Second-to-last field |
| `$(NF-2)` | Third-to-last field |
| `NF` | Number of fields in the current record |
| `NR` | Total record number (cumulative across all files) |
| `FNR` | Record number within the current file (resets per file) |

---

## Basic Field Printing

```awk
# Print first and third column (whitespace-delimited)
awk '{ print $1, $3 }' file.txt

# Print last field of each line
awk '{ print $NF }' file.txt

# Print second-to-last field
awk '{ print $(NF-1) }' file.txt

# Print the entire line
awk '{ print $0 }' file.txt
# same as: awk '1' file.txt  or just: cat file.txt

# Print all fields except the first
awk '{ $1=""; print }' file.txt

# Print fields 2 through 4
awk '{ print $2, $3, $4 }' file.txt

# Print fields in reverse order
awk '{ for(i=NF; i>=1; i--) printf "%s%s", $i, (i>1?" ":"\n") }' file.txt
```

---

## Field Separators

```awk
# Tab-separated (TSV)
awk -F'\t' '{ print $2 }' data.tsv

# Comma-separated (CSV — simple, no quoted fields)
awk -F',' '{ print $3 }' data.csv

# Colon-separated (like /etc/passwd)
awk -F':' '{ print $1, $3 }' /etc/passwd

# Set FS in BEGIN block (equivalent to -F)
awk 'BEGIN{FS=":"} { print $1, $3 }' /etc/passwd

# Regex separator: split on comma OR semicolon OR pipe
awk -F'[,;|]' '{ print $1 }' mixed.txt

# Multi-character separator string
awk -F' :: ' '{ print $1 }' structured.txt

# Default FS: whitespace
# When FS=" " (the default), awk splits on runs of whitespace
# and ignores leading/trailing whitespace — this is special behavior.
# Any other FS value does NOT ignore leading whitespace.
```

---

## Modifying Fields

```awk
# Assign to a field — awk reconstructs $0 using OFS
awk -F':' 'BEGIN{OFS=":"} { $3=9999; print }' /etc/passwd
# Replaces UID field with 9999 in the output

# Append to a field
awk '{ $1 = $1 "_modified"; print }' file.txt

# Add a new field
awk '{ $(NF+1) = "extra"; print }' file.txt

# Assign to $0 to re-split
awk '{ $0 = toupper($0); print $1 }' file.txt
# After assigning to $0, awk re-splits into fields
```

!!! warning "OFS and field assignment"
    When you **assign to any field** (including `$1`), awk reconstructs `$0` by joining all fields with `OFS`. If you haven't set `OFS`, it defaults to a single space. Set `OFS` in `BEGIN` before modifying fields if you want to preserve the original delimiter.

---

## Record Separators

```awk
# Default: RS="\n" — one record per line

# Paragraph mode: blank line separates records
awk 'BEGIN{RS=""} { print NR, NF }' paragraphs.txt

# Each record is separated by "---\n"
awk 'BEGIN{RS="---\n"} { print NR, NF }' docs.txt

# gawk: RS can be a regex
awk 'BEGIN{RS="[0-9]+"} { print }' file.txt
```

---

## Line Numbers

```awk
# Show line number alongside content
awk '{ print NR ": " $0 }' file.txt

# Skip the header line
awk 'NR > 1 { print }' file.txt

# Print only lines 5 through 10
awk 'NR==5, NR==10 { print }' file.txt

# Show filename and line number (multiple files)
awk '{ print FILENAME ":" FNR " " $0 }' *.log

# Print only lines with more than 5 fields
awk 'NF > 5' file.txt

# Print only non-empty lines
awk 'NF > 0' file.txt
# or:
awk 'NF' file.txt
```

---

## Multiple Files

```awk
# Process header from file1, data from file2
# NR==FNR is true only while reading the first file
awk 'NR==FNR { header[NR]=$0; next } { print header[FNR], $0 }' head.txt data.txt

# Print FNR vs NR to understand the difference
awk '{ print FILENAME, FNR, NR, $0 }' file1.txt file2.txt
```
