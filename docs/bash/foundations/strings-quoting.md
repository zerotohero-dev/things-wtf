# Strings & Quoting


```bash title="quoting rules"
# Double quotes: variable expansion + command substitution, no word-split
echo "Hello $name, today is $(date)"

# Single quotes: NOTHING is expanded, literal string
echo '$HOME is literally $HOME — no expansion'

# $'...' — ANSI-C quoting, allows escape sequences
echo $'line1\nline2\ttabbed'
sep=$'\t'     # literal tab character
nul=$'\0'     # null byte

# RULE: ALWAYS double-quote variable expansions
# BAD:  cp $src $dst   (breaks if path has spaces)
# GOOD: cp "$src" "$dst"

# EXCEPTION: arithmetic context, [[ ]], and assignment RHS
if [[ $count -gt 0 ]]; then echo "ok"; fi  # fine unquoted inside [[]]
```


```bash title="string operations"
s="Hello, World!"

# Length
echo "${#s}"           # 13

# Substring: ${var:offset:length}
echo "${s:7:5}"        # World
echo "${s:(-6)}"       # orld!  (negative = from end)

# Case conversion (bash 4+)
echo "${s,,}"           # hello, world!  (all lower)
echo "${s^^}"           # HELLO, WORLD!  (all upper)
echo "${s,}"            # hEllo, World!  (first char lower)
echo "${s^}"            # Hello, World!  (first char upper)

# Replace: ${var/pattern/replacement}
echo "${s/World/Bash}"   # Hello, Bash!   (first match)
echo "${s//l/L}"        # HeLLo, WorLd!  (all matches)
echo "${s/#Hello/Hi}"   # Hi, World!     (prefix match)
echo "${s/%!/...}"      # Hello, World...  (suffix match)

# Trim: # = prefix, % = suffix, ## / %% = greedy
path="/usr/local/bin/bash"
echo "${path##*/}"      # bash    (basename)
echo "${path%/*}"       # /usr/local/bin  (dirname)
file="archive.tar.gz"
echo "${file%.gz}"      # archive.tar     (strip .gz)
echo "${file%%.*}"      # archive         (strip all extensions)

# Test if contains substring
[[ "$s" == *"World"* ]] && echo "contains World"

# Multiline string
multi="line one
line two
line three"

# Heredoc (assigned to var)
text=$(cat <<EOF
  Hello $name
  Today is $(date)
EOF
)
```
