# awk — Arrays

awk arrays are **associative** (hash maps). Any string or number can be a key. Arrays need no declaration and grow dynamically.

---

## Basics

```awk
# Create and access
awk '{ arr["key"] = "value"; print arr["key"] }'

# Integer keys work too (but are still strings internally)
awk '{ arr[1] = "one"; arr[2] = "two"; print arr[1] }'

# Auto-initialize: unset elements are "" or 0
awk 'BEGIN { print arr["missing"] + 0 }'   # prints 0
```

---

## Common Patterns

### Count occurrences

```awk
awk '{ count[$1]++ }
END { for (k in count) print k, count[k] }' file.txt
```

### Count and sort descending

```awk
awk '{ count[$1]++ }
END { for (k in count) print count[k], k }' file.txt \
  | sort -rn
```

### Deduplicate lines (preserve order, keep first)

```awk
awk '!seen[$0]++' file.txt
# !seen[$0]++ evaluates to:
#   first time:  seen[$0]=0 → increment → ! 0 = true  → print
#   after that:  seen[$0]=1 → increment → ! 1 = false → skip
```

### Group values by key

```awk
awk '{
  if ($1 in groups) groups[$1] = groups[$1] "," $2
  else              groups[$1] = $2
}
END { for (k in groups) print k, groups[k] }' file.txt
```

### Frequency histogram

```awk
awk '{
  freq[$1]++
}
END {
  for (v in freq) {
    printf "%-20s %d ", v, freq[v]
    for (i=0; i<freq[v]; i++) printf "#"
    print ""
  }
}' file.txt
```

---

## Checking and Deleting

```awk
# Test if a key exists (does NOT create the element)
awk '{ if ("foo" in arr) print "found" }' file.txt

# Never do this to test — it creates the element as a side effect:
# if (arr["foo"] == "") ...   ← BAD: adds "foo" to the array

# Delete a single key
awk '{ delete arr[$1] }' file.txt

# Delete an entire array (gawk)
awk 'END { delete arr }' file.txt

# Iterate and delete while iterating (safe in gawk)
awk 'END {
  for (k in arr)
    if (arr[k] < threshold) delete arr[k]
}' file.txt
```

---

## Two-file Join (Classic Pattern)

```awk
# NR==FNR is true only while reading the FIRST file
# Use this to load one file into an array, then join against the second

# Inner join: print lines from file2 where $1 matches a key from file1
awk 'NR==FNR { lookup[$1]=$2; next }
     $1 in lookup { print $0, lookup[$1] }' file1.txt file2.txt

# Left join: print all lines from file2, adding data from file1 if available
awk 'NR==FNR { lookup[$1]=$2; next }
     { print $0, ($1 in lookup ? lookup[$1] : "N/A") }' file1.txt file2.txt

# Lines in file2 NOT in file1 (like comm -23 but field-based)
awk 'NR==FNR { seen[$0]=1; next } !seen[$0]' file1.txt file2.txt
```

---

## Multi-dimensional Arrays

### gawk native (true multi-dim)

```awk
awk '{
  matrix[$1][$2]++
}
END {
  for (a in matrix)
    for (b in matrix[a])
      print a, b, matrix[a][b]
}' file.txt
```

### POSIX SUBSEP style (portable)

awk uses `SUBSEP` (`\034`, FS 28) as a compound key separator:

```awk
awk '{
  count[$1, $2]++     # key is actually "$1 SUBSEP $2"
}
END {
  for (key in count) {
    split(key, parts, SUBSEP)
    print parts[1], parts[2], count[key]
  }
}' file.txt

# Test multi-dim key existence
awk '{ if (($1, $2) in matrix) print "exists" }' file.txt
```

---

## Sorting Arrays (gawk)

```awk
# Sort values numerically
awk '{ val[NR] = $1 }
END {
  n = asort(val)          # sorts by VALUE, returns count
  for (i=1; i<=n; i++) print val[i]
}' data.txt

# Sort keys
awk '{ count[$1]++ }
END {
  n = asorti(count, sorted)   # sorts KEYS into sorted[], returns count
  for (i=1; i<=n; i++) print sorted[i], count[sorted[i]]
}' file.txt

# Sort by value descending (pipe approach — simpler)
awk '{ count[$1]++ }
END { for (k in count) print count[k], k }' file.txt | sort -rn
```

---

## Arrays as Sets

```awk
# Build a set from file1, then filter file2
awk 'NR==FNR { allowed[$0]=1; next }
     $1 in allowed { print }' allowlist.txt data.txt

# Intersection of two files (lines present in both)
awk 'NR==FNR { a[$0]=1; next } $0 in a' file1.txt file2.txt

# Union (all lines from both, deduplicated)
awk '{ seen[$0]=1 } END { for (k in seen) print k }' file1.txt file2.txt
```
