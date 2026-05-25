# Functions


```bash title="declaration, arguments, return values"
# Two syntaxes — prefer the function keyword form
greet() { echo "Hello $1"; }            # POSIX style
function greet { echo "Hello $1"; }      # bash style
function greet() { echo "Hello $1"; }    # both (preferred)

# Arguments: same as script ($1, $2, ... $@, $#)
function add() {
  local a="$1"  local b="$2"
  echo "$(( a + b ))"  # return value via stdout
}
result=$(add 3 4)   # capture output: 7

# return — only sets exit code (0-255), NOT a value
function is_root() {
  [[ $EUID -eq 0 ]]  # return value is last command's exit code
}
is_root && echo "running as root"

# local — critical for avoiding global variable leaks
function myfunc() {
  local tmp="$1"
  local -i count=0  # local integer
  local -a arr      # local array
  local -A map      # local assoc array
}

# Returning values via nameref (bash 4.3+) — avoids subshell overhead
function get_value() {
  local -n _ref="$1"  # nameref — _ref IS the variable named in $1
  _ref="computed value"
}
myvar=""
get_value myvar   # myvar is now "computed value" — no subshell!

# Recursion — with local for proper stack frames
function factorial() {
  local n="$1"
  [[ $n -le 1 ]] && { echo 1; return; }
  echo $(( n * $(factorial $((n - 1))) ))
}

# List all defined functions
declare -F              # function names
declare -f myfunc      # function source code
```


!!! tip "always use local"
    Without local, variables in functions are global and will clobber outer scope variables with the same name. Make it a reflex to declare local for every function variable.


!!! info "nameref vs subshell return"
    result=$(myfunc) spawns a subshell — can't modify the parent environment, costs a fork. Nameref (local -n) assigns directly into the caller's scope with no subshell. Prefer nameref for performance-critical loops.
