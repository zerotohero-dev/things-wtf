# awk — Practical Recipes

Real-world programs organized by domain. Each one is a self-contained, runnable example.

---

## Log Analysis

### HTTP status code summary

```awk
# Common Log Format: field 9 is the status code
awk '{ count[$9]++ }
END {
  for (s in count) print s, count[s]
}' access.log | sort -k1
```

### Top 10 IPs by request count

```awk
awk '{ count[$1]++ }
END { for (ip in count) print count[ip], ip }' access.log \
  | sort -rn | head -10
```

### Requests per minute

```awk
# CLF timestamp: [15/Jan/2024:09:01:45 +0000]
awk '{
  match($4, /\[([^:]+:[0-9]+:[0-9]+)/, m)
  minute = m[1]
  count[minute]++
}
END { for (m in count) print m, count[m] }' access.log | sort
```

### Colorize log levels

```awk
tail -f app.log | awk '
  /ERROR/ { print "\033[31m" $0 "\033[0m"; next }
  /WARN/  { print "\033[33m" $0 "\033[0m"; next }
  /INFO/  { print "\033[32m" $0 "\033[0m"; next }
           { print }
'
```

### Calculate p50/p95/p99 latency

```awk
sort -n latencies.txt | awk '
  { lines[NR] = $1 }
  END {
    printf "p50: %g\n", lines[int(NR*0.50)]
    printf "p95: %g\n", lines[int(NR*0.95)]
    printf "p99: %g\n", lines[int(NR*0.99)]
    printf "p999: %g\n", lines[int(NR*0.999)]
  }
'
```

---

## Data Transformation

### Reformat date from YYYY-MM-DD to DD/MM/YYYY

```awk
awk '{
  if (match($0, /([0-9]{4})-([0-9]{2})-([0-9]{2})/, m))
    printf "%s/%s/%s\n", m[3], m[2], m[1]
}' dates.txt
```

### CSV to TSV

```awk
awk 'BEGIN{FS=","; OFS="\t"} { $1=$1; print }' data.csv
```

### TSV to Markdown table

```awk
awk -F'\t' '
NR==1 {
  printf "| "
  for (i=1; i<=NF; i++) printf "%s | ", $i
  printf "\n| "
  for (i=1; i<=NF; i++) printf "--- | "
  printf "\n"
  next
}
{
  printf "| "
  for (i=1; i<=NF; i++) printf "%s | ", $i
  printf "\n"
}' data.tsv
```

### Column-aligned output with printf

```awk
awk '
BEGIN { printf "%-20s %10s %8s\n", "NAME", "SIZE", "STATUS" }
      { printf "%-20s %10d %8s\n", $1, $2, $3 }
' data.txt
```

### Transpose a matrix (rows ↔ columns)

```awk
awk '{
  for (i=1; i<=NF; i++) matrix[NR][i] = $i
  if (NF > maxcols) maxcols = NF
}
END {
  for (j=1; j<=maxcols; j++) {
    for (i=1; i<=NR; i++) printf "%s%s", matrix[i][j], (i<NR?" ":"\n")
  }
}' matrix.txt
```

---

## File Comparison & Set Operations

### Lines in file2 but NOT in file1

```awk
awk 'NR==FNR { seen[$0]=1; next } !seen[$0]' file1.txt file2.txt
```

### Lines common to both files (intersection)

```awk
awk 'NR==FNR { a[$0]=1; next } $0 in a' file1.txt file2.txt
```

### Inner join on field 1

```awk
awk -F'\t' '
  NR==FNR { a[$1]=$2; next }
  $1 in a { print $1, a[$1], $2 }
' file1.tsv file2.tsv
```

### Left join (all rows from file2, augmented with file1 data)

```awk
awk -F'\t' '
  NR==FNR { a[$1]=$2; next }
  { print $0, ($1 in a ? a[$1] : "N/A") }
' lookup.tsv data.tsv
```

---

## Text Processing

### Word frequency count

```awk
awk '{
  for (i=1; i<=NF; i++) {
    word = tolower($i)
    gsub(/[^a-z]/, "", word)
    if (word != "") freq[word]++
  }
}
END {
  for (w in freq) print freq[w], w
}' text.txt | sort -rn | head -20
```

### Deduplicate lines (preserve order)

```awk
awk '!seen[$0]++' file.txt
```

### Line length statistics

```awk
awk '{
  len = length($0)
  total += len
  if (NR==1 || len < min) min = len
  if (NR==1 || len > max) max = len
}
END {
  print "lines:", NR
  print "min length:", min
  print "max length:", max
  print "avg length:", total/NR
}' file.txt
```

---

## Kubernetes / DevOps

### Extract pod name and node

```bash
kubectl get pods -A -o wide | awk 'NR>1 { print $2, $8 }'
```

### Watch for pods not running

```bash
kubectl get pods -A | awk 'NR>1 && $4 != "Running" && $4 != "Completed" { print }'
```

### Summarize resource requests from manifests

```bash
grep -r 'memory:' k8s/ | awk -F': ' '{ print $2 }' | sort | uniq -c | sort -rn
```

### Parse Helm values into key=value pairs

```bash
helm show values mychart | awk '
  /^[a-zA-Z]/ { section=$1 }
  /^  [a-zA-Z]/ {
    gsub(/: /, "=", $0)
    gsub(/^  /, "", $0)
    print section "." $0
  }
'
```

---

## Security & Compliance

### Find world-writable files from `ls -la`

```bash
ls -laR /etc | awk '$1 ~ /^.......w/ { print $NF }'
```

### Summarize /etc/passwd shells

```bash
awk -F: '{ shells[$NF]++ } END { for (s in shells) print shells[s], s }' /etc/passwd | sort -rn
```

### Redact secrets from logs before shipping

```bash
awk '{ gsub(/(password|token|secret)=[^ &]+/, "\\1=REDACTED"); print }' app.log
```
