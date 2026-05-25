# Loops


```bash title="all loop forms"
# for-in (most common)
for item in "${array[@]}"; do
  echo "$item"
done

# for-in over files
for f in /etc/*.conf; do   # glob expands before loop starts
  [[ -f "$f" ]] || continue  # guard against empty glob
  echo "$f"
done

# C-style for loop
for ((i=0; i<10; i++)); do
  echo "$i"
done

# brace expansion sequence
for i in {1..5}; do echo "$i"; done
for i in {0..20..5}; do echo "$i"; done  # 0 5 10 15 20 (step)

# while loop
count=0
while [[ $count -lt 5 ]]; do
  echo "$count"
  ((count++)) || true
done

# Infinite loop
while true; do
  echo "running..."
  sleep 1
done

# until loop (opposite of while)
until ping -c1 "$host" &> /dev/null; do
  echo "waiting for $host..."
  sleep 2
done

# Read file line by line (safest method)
while IFS= read -r line; do
  echo "$line"
done < "file.txt"

# Read from command output
while IFS= read -r line; do
  echo "$line"
done < <(find /etc -name '*.conf')

# break and continue
for i in {1..10}; do
  [[ "$i" -eq 3 ]] && continue  # skip 3
  [[ "$i" -eq 7 ]] && break     # stop at 7
  echo "$i"
done

# break N — break out of N nested loops
for i in {1..3}; do
  for j in {1..3}; do
    [[ "$i" -eq 2 && "$j" -eq 2 ]] && break 2  # exits both loops
  done
done
```


!!! warning "for f in *.txt — empty glob"
    If no files match, the literal string *.txt is passed to the loop body. Guard with [[ -f "$f" ]] || continue or enable shopt -s nullglob (makes unmatched globs expand to nothing).
