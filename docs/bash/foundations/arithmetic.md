# Arithmetic


```bash title="arithmetic expressions"
# $(( )) — arithmetic expansion (returns value)
x=$((3 + 4))          # 7
y=$(($x * 2 - 1))     # 13
z=$((10 / 3))          # 3 (integer division)
r=$((10 % 3))          # 1 (modulo)
p=$((2 ** 8))          # 256 (exponent)

# Bitwise operators
a=$((0xFF & 0x0F))     # AND: 15
b=$((1 << 4))          # shift left: 16

# Ternary
result=$(($x > 5 ? 1 : 0))

# Increment/decrement
$((count++))   # post-increment
$((++count))   # pre-increment
((count+=5))   # compound assignment

# (( )) — arithmetic command (exits 0 if non-zero result)
if (($count > 10)); then echo "big"; fi
((count++)) || true     # || true protects from set -e when count was 0

# Floating point — bash only does integers; use bc or awk
result=$(echo "scale=4; 22/7" | bc)
result=$(awk 'BEGIN {printf "%.4f\n", 22/7}')
```


!!! warning "((count++)) and set -e"
    ((expr)) returns exit code 1 when the expression evaluates to 0 (falsy by arithmetic rules). So ((count++)) when count is 0 increments it but returns 1, which kills the script under set -e. Use ((count++)) || true or ((count += 1)) instead.
