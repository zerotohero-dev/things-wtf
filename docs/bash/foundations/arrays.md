# Arrays


```bash title="indexed arrays"
# Declare and initialize
fruits=("apple" "banana" "cherry")
declare -a fruits

# Access
echo "${fruits[0]}"    # apple
echo "${fruits[-1]}"   # cherry (last)
echo "${fruits[@]}"    # all elements
echo "${#fruits[@]}"   # count: 3
echo "${!fruits[@]}"   # indices: 0 1 2

# Append
fruits+=("grape")

# Slice: ${arr[@]:offset:len}
echo "${fruits[@]:1:2}" # banana cherry

# Delete element
unset 'fruits[1]'  # leaves hole!

# Re-index after delete
fruits=("${fruits[@]}")

# Loop (ALWAYS quote "${arr[@]}")
for f in "${fruits[@]}"; do
  echo "$f"
done

# Split string into array
IFS=',' read -ra parts <<< "a,b,c"

# Read lines into array
mapfile -t lines < "file.txt"
readarray -t lines < "file.txt" # same
```


```bash title="associative arrays (bash 4+)"
# MUST use declare -A
declare -A config
config=(
  [host]="localhost"
  [port]="8080"
  [debug]="true"
)

# Access
echo "${config[host]}"   # localhost

# All keys
echo "${!config[@]}"    # host port debug

# All values
echo "${config[@]}"

# Check key exists
[[ -v "config[host]" ]] && echo "exists"

# Loop key-value
for key in "${!config[@]}"; do
  echo "$key = ${config[$key]}"
done

# Delete key
unset 'config[debug]'

# Count
echo "${#config[@]}"    # 2
```


!!! warning "Array quoting — the most common bug"
    ${array[@]} unquoted word-splits elements with spaces. Always use "${array[@]}". Use "${array[*]}" only when you explicitly want a single string with IFS separator.
