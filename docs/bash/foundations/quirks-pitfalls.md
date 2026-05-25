# Quirks & Pitfalls

> **read this twice**


### Zero = Success, not Truthy


Exit code 0 = success = true in if/while. Exit code 1+ = failure = false. The OPPOSITE of most languages where 0 is falsy. if grep -q ... works because grep returns 0 when found.


```bash title="exit codes"
# 0 = true/success in bash
if grep -q "pattern" file; then
  echo "found"    # grep returned 0
fi
# true is a command that exits 0
# false is a command that exits 1
[[ 1 -eq 1 ]]  # exits 0 (true)
[[ 1 -eq 2 ]]  # exits 1 (false)
```


### Word Splitting & Glob Expansion


Unquoted variables undergo word splitting (on IFS) AND glob expansion. A variable containing *.txt expands to matching files. Always double-quote.


```bash title="quoting"
f="my file.txt"
rm $f        # rm "my" "file.txt" — TWO args
rm "$f"     # rm "my file.txt" — correct

pattern="*.txt"
echo $pattern   # lists matching files!
echo "$pattern" # prints literal *.txt
```


### [ ] vs [[ ]]  Silent Differences


[ $a == $b ] — word splits; if $a is empty, becomes [ == $b ] = syntax error. [[ ]] is safe. Also: [ ] uses = for strings, -eq for numbers; mixing them gives wrong results silently.


```bash title="test traps"
a=""
[ $a = "foo" ]   # syntax error!
[[ $a == "foo" ]]  # fine, a is empty
[ "02" = "2" ]   # false (string compare)
[[ 02 -eq 2 ]]   # true  (numeric)
```


### Spaces Around = in Assignment


var = value is NOT assignment — it runs the command var with arguments = and value. Assignment requires NO spaces: var=value. Probably the #1 bash beginner bug.


```bash title="assignment"
x = 5      # "command not found: x"
x=5        # correct
x=5 cmd   # sets x=5 ONLY for this cmd
x =5       # "command not found: x"
```


### Piped while Loses Variables


Each element of a pipeline runs in a subshell. Variables set inside cmd | while read... are lost after the loop. Use process substitution while read; done < <(cmd) instead.


```bash title="subshell scoping"
n=0
seq 5 | while read i; do ((n++)); done
echo $n    # 0 !!!
# fix:
while read i; do ((n++))||true; done < <(seq 5)
echo $n    # 5
```


### set -e and command substitution


A failing command inside $() does NOT trigger set -e if the substitution is used in an assignment. var=$(failing_cmd) — the assignment itself succeeds (exit 0), the failure is swallowed.


```bash title="-e trap"
set -e
# BUG: this does NOT abort the script
result=$(false; echo "hi")
# because the assignment returned 0

# fix: separate them
result=$(failing_cmd)  # still bad
failing_cmd; result=$?  # explicit check
```


### IFS and read


read splits on $IFS (default: space, tab, newline). Also strips leading/trailing whitespace. Use IFS= read -r line to read verbatim lines with exact whitespace preserved.


```bash title="read gotchas"
# strips leading/trailing space and backslash
read line <<< "  hello  "   # "hello"
# verbatim:
IFS= read -r line <<< "  hello  "  # "  hello  "
# CSV split:
IFS=',' read -r a b c <<< "x,y,z"
```


### Glob with no matches


By default, *.txt with no matches is passed as the literal string *.txt to the command. Use shopt -s nullglob to expand to nothing, or shopt -s failglob to error.


```bash title="glob behavior"
# default: literal if no match
for f in /tmp/*.nonexistent; do
  echo "$f"  # prints "/tmp/*.nonexistent"
done
# fix:
shopt -s nullglob
for f in /tmp/*.nonexistent; do
  echo "$f"  # never executes
done
```
