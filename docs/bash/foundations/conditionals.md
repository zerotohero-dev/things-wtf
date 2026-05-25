# Conditionals


```bash title="if / elif / else"
if [[ -f "$file" ]]; then
  echo "exists"
elif [[ -d "$file" ]]; then
  echo "is a directory"
else
  echo "doesn't exist"
fi

# Short-circuit  (cmd runs only if condition is true/false)
[[ -d "$dir" ]] || mkdir -p "$dir"  # create if missing
[[ -f "$lock" ]] && die "already running"  # abort if locked

# Negation
if ! command -v kubectl &> /dev/null; then
  echo "kubectl not found"
fi
```


```bash title="[[ ]] vs [ ] vs test"
# [ ] = POSIX test, an actual command — split/glob apply, need quoting
# [[ ]] = bash keyword — no word-split, no glob, supports regex & logical ops
# PREFER [[  ]] in bash scripts

# [[ ]] advantages:
[[ "$s" == foo* ]]         # glob pattern (no quotes on pattern)
[[ "$s" =~ ^foo[0-9]+$ ]]  # regex! =~ operator (no quotes on regex)
echo "${BASH_REMATCH[0]}"    # full match
echo "${BASH_REMATCH[1]}"    # capture group 1

[[ -f "$a" && -r "$a" ]]     # logical AND inside [[ ]]
[[ -z "$a" || -z "$b" ]]    # logical OR inside [[ ]]

# Still need [ ] for POSIX sh compatibility
# [ "$a" = "$b" ]  note: single = in POSIX, == in bash ok too
```


| Operator | Tests |
| --- | --- |
| -f file | file exists and is a regular file |
| -d dir | directory exists |
| -e path | path exists (any type) |
| -s file | file exists and has size > 0 |
| -r/-w/-x | readable / writable / executable |
| -L path | symlink exists |
| -z str | string is empty (zero length) |
| -n str | string is non-empty |
| a == b | strings equal (glob in [[]]) |
| a != b | strings not equal |
| a =~ regex | regex match ([[]] only) |
| a -eq b | integers equal |
| a -ne/-lt/-le/-gt/-ge b | integer comparisons |
| -v varname | variable is set (bash 4.2+) |
| f1 -nt f2 | f1 newer than f2 (mtime) |
| f1 -ot f2 | f1 older than f2 |
