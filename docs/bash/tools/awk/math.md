# awk — Math Functions

awk treats any string that looks like a number as numeric in arithmetic context. Uninitialized variables are 0 in numeric context and `""` in string context.

---

## Built-in Math Functions

| Function | Description |
|----------|-------------|
| `int(x)` | Truncate to integer (towards zero, not floor) |
| `sqrt(x)` | Square root |
| `exp(x)` | e^x |
| `log(x)` | Natural logarithm (base e) |
| `sin(x)` | Sine (x in radians) |
| `cos(x)` | Cosine (x in radians) |
| `atan2(y, x)` | Arc tangent of y/x in radians; handles all quadrants |
| `rand()` | Pseudo-random float in `[0, 1)` |
| `srand([x])` | Seed the random number generator; returns previous seed |

---

## Arithmetic Operators

| Operator | Meaning |
|----------|---------|
| `+`, `-`, `*`, `/` | Basic arithmetic |
| `%` | Modulo |
| `^` or `**` | Exponentiation |
| `++x`, `x++` | Pre/post increment |
| `--x`, `x--` | Pre/post decrement |
| `+=`, `-=`, `*=`, `/=`, `%=`, `^=` | Compound assignment |

---

## Aggregation Patterns

### Sum a column

```awk
awk '{ sum += $3 } END { print sum }' data.txt
```

### Average

```awk
awk '{ sum += $1; count++ } END { print sum / count }' data.txt
```

### Min and max

```awk
awk '
  NR==1 { min=$1; max=$1 }
  {
    if ($1 < min) min = $1
    if ($1 > max) max = $1
  }
  END { print "min:", min, "max:", max }
' data.txt
```

### Standard deviation

```awk
awk '
  { sum += $1; sumsq += $1*$1; n++ }
  END {
    mean = sum / n
    variance = sumsq/n - mean^2
    print "mean:", mean
    print "stddev:", sqrt(variance)
  }
' data.txt
```

### Running total / cumulative sum

```awk
awk '{ cumsum += $1; print $0, cumsum }' data.txt
```

---

## Percentile (with pre-sorted input)

```awk
sort -n latencies.txt | awk '
  { lines[NR] = $1 }
  END {
    p50 = lines[int(NR * 0.50)]
    p95 = lines[int(NR * 0.95)]
    p99 = lines[int(NR * 0.99)]
    print "p50:", p50
    print "p95:", p95
    print "p99:", p99
  }
'
```

---

## Numeric Formatting

```awk
# Two decimal places
awk '{ printf "%.2f\n", $1 }' data.txt

# Convert bytes to human-readable
awk '{
  b = $1
  if      (b >= 2^30) printf "%.2f GiB\n", b/2^30
  else if (b >= 2^20) printf "%.2f MiB\n", b/2^20
  else if (b >= 2^10) printf "%.2f KiB\n", b/2^10
  else                printf "%d B\n", b
}' bytes.txt

# Hex output
awk '{ printf "0x%X\n", $1 }' decimals.txt

# Octal output
awk '{ printf "%o\n", $1 }' decimals.txt
```

---

## Random Numbers

```awk
# Seed once in BEGIN, then use rand() in body
awk 'BEGIN { srand() } rand() < 0.1' bigfile.txt   # ~10% sample

# Random integer in [1, N]
awk 'BEGIN { srand(); n=100; print int(rand()*n) + 1 }'

# Shuffle lines (Knuth shuffle)
awk 'BEGIN { srand() }
     { lines[NR] = $0 }
     END {
       for (i=NR; i>1; i--) {
         j = int(rand()*i) + 1
         tmp = lines[i]; lines[i] = lines[j]; lines[j] = tmp
       }
       for (i=1; i<=NR; i++) print lines[i]
     }' file.txt
```

---

## Integer and Modulo

```awk
# Integer division
awk '{ print int($1 / $2) }' data.txt

# Modulo
awk '{ print $1 % 3 }' data.txt

# Check if even/odd
awk '{ print $1, ($1 % 2 == 0 ? "even" : "odd") }' nums.txt

# int() truncates towards zero (not floor)
# int(-3.9) = -3  (not -4)
awk 'BEGIN { print int(-3.9) }'   # prints -3
```

---

## String ↔ Number Coercion

```awk
# String in numeric context → converted automatically
awk '{ print $1 + 0 }' data.txt   # forces numeric interpretation

# Uninitialized variables are 0 numerically, "" as string
awk 'BEGIN { print x+0, x"str" }'   # prints "0 str"

# strtonum: handles hex/octal explicitly (gawk)
awk '{ print strtonum($1) }' hex_values.txt   # "0xFF" → 255
```
