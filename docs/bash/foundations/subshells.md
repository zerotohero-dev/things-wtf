# Subshells vs Command Groups


```bash title="( ) subshell vs { } group"
# ( ) — subshell: forks a new process, changes are isolated
x=1
( x=99; cd /tmp; echo "$x" )   # prints 99
echo "$x"                       # still 1 — subshell change isolated
echo "$PWD"                     # original dir — cd isolated

# Use ( ) to isolate side-effects:
(
  cd /some/dir
  source env.sh         # won't pollute current env
  ./script.sh
)

# { } — command group: same shell, no fork, changes persist
{
  x=99
  echo "inside group"
}                        # note: semicolon/newline before }
echo "$x"               # 99 — change persists

# { } for grouping redirections (only one redirection needed)
{
  echo "header"
  cat data.txt
  echo "footer"
} > output.txt

# { } for error handling group
{
  step1 &&
  step2 &&
  step3
} || {
  echo "pipeline failed"
  rollback
}

# Subshell pipeline variable scope trap
count=0
# WRONG: cmd runs in subshell, count changes lost
echo "a b c" | while read w; do ((count++))||true; done; echo $count  # 0!
# CORRECT: process substitution keeps parent shell
while read w; do ((count++))||true; done < <(echo "a b c"); echo $count  # 3
```
