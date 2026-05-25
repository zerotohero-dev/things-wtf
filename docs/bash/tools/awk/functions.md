# awk — User-Defined Functions

awk supports full user-defined functions with parameters, return values, and recursive calls. Functions are global and can be called from any rule.

---

## Syntax

```awk
function name(param1, param2,    local1, local2) {
  # body
  return value
}
```

Functions are defined at the top level, alongside `BEGIN`/`END` rules. Call order doesn't matter — you can call a function defined later in the script.

---

## Local Variables Idiom

awk has **no local variable declaration**. The convention is to add extra parameters after the real parameters, separated by extra whitespace. These extra parameters will be `""` / `0` when the function is called, acting as local variables.

```awk
function process(input,    result, i, tmp) {
  # result, i, tmp are "local" — callers don't pass them
  result = ""
  for (i = 1; i <= length(input); i++) {
    tmp = substr(input, i, 1)
    result = result toupper(tmp)
  }
  return result
}
```

---

## Utility Functions

```awk
awk '
# Maximum of two values
function max(a, b) {
  return (a > b) ? a : b
}

# Minimum of two values
function min(a, b) {
  return (a < b) ? a : b
}

# Absolute value
function abs(x) {
  return (x < 0) ? -x : x
}

# Trim leading and trailing whitespace
function trim(s,    result) {
  result = s
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", result)
  return result
}

# Repeat string n times
function repeat(s, n,    result, i) {
  result = ""
  for (i = 0; i < n; i++) result = result s
  return result
}

# Check if string starts with prefix
function startswith(s, prefix) {
  return substr(s, 1, length(prefix)) == prefix
}

# Check if string ends with suffix
function endswith(s, suffix) {
  return substr(s, length(s) - length(suffix) + 1) == suffix
}

{ print trim($0), max($2, $3) }
' data.txt
```

---

## Recursive Functions

gawk supports recursion. Be careful of stack depth on very large inputs.

```awk
awk '
function factorial(n) {
  if (n <= 1) return 1
  return n * factorial(n - 1)
}

function fib(n) {
  if (n <= 1) return n
  return fib(n-1) + fib(n-2)
}

{ print $1, factorial($1) }
'
```

---

## Arrays as Parameters

Arrays are always passed **by reference**. This lets functions populate arrays that are accessible to the caller.

```awk
awk '
function fill_squares(arr, n,    i) {
  for (i = 1; i <= n; i++) arr[i] = i * i
}

function keys_sorted(src, dst,    tmp) {
  # copy keys of src into dst as a numerically-sorted array
  # (simple bubble sort for illustration)
  n = asorti(src, dst)
  return n
}

BEGIN {
  fill_squares(sq, 5)
  for (i=1; i<=5; i++) print i, sq[i]
}
' /dev/null
```

---

## Putting It All Together: A Small awk Program

```awk
#!/usr/bin/awk -f
# csv_summary.awk — summarize a CSV: count rows, sum column N, show min/max
# Usage: awk -v col=3 -f csv_summary.awk data.csv

function update_stats(val,    n) {
  count++
  total += val
  if (count == 1 || val < minval) minval = val
  if (count == 1 || val > maxval) maxval = val
}

BEGIN {
  FS = ","
  if (!col) col = 1
  count = 0; total = 0
}

NR == 1 {
  next   # skip header
}

{
  update_stats($col + 0)
}

END {
  if (count == 0) { print "No data"; exit 1 }
  printf "rows:    %d\n",          count
  printf "sum:     %.4g\n",        total
  printf "mean:    %.4g\n",        total / count
  printf "min:     %.4g\n",        minval
  printf "max:     %.4g\n",        maxval
  printf "range:   %.4g\n",        maxval - minval
}
```

Save as `csv_summary.awk` and run:

```bash
awk -v col=3 -f csv_summary.awk data.csv
```

---

!!! tip "Function files"
    For large awk programs, put shared functions in a `lib.awk` file and include multiple `-f` flags:
    ```bash
    awk -f lib.awk -f main.awk data.txt
    ```
    The functions in `lib.awk` are visible to rules in `main.awk`.
