# Variables


```bash title="declaration & scope"
# Assignment — NO spaces around =
name="volkan"
count=42
empty=""

# Read-only (const)
readonly PI=3.14159
declare -r PI=3.14159  # equivalent

# Export to child processes
export MY_VAR="value"
declare -x MY_VAR="value"

# Integer type (arithmetic operations auto-applied)
declare -i num=10

# Unset a variable
unset name

# Check if set
[[ -v MY_VAR ]] && echo "set"
[[ -z "${MY_VAR:-}" ]] && echo "empty or unset"
```


```bash title="special / automatic variables"
$0          # script name (or shell name if interactive)
$1 $2 $9     # positional args
${10}       # 10th arg — braces required for 2+ digits
$#          # number of arguments
$@          # all args as separate words (preserves quoting)
$*          # all args as single string (DON'T use this, use $@)
$?          # exit code of last command
$$          # PID of current shell
$!          # PID of last backgrounded process
$_          # last argument of previous command
$-          # current shell option flags (e.g. "hB" or "exu")
$BASHPID    # PID of current bash process (differs from $$ in subshells)
$BASH_SOURCE  # array of source file names in call stack
$LINENO     # current line number
$FUNCNAME   # array of function names in call stack
$PIPESTATUS # array of exit codes of last pipeline: echo "${PIPESTATUS[@]}"
$IFS        # Internal Field Separator (default: space, tab, newline)
$RANDOM     # pseudo-random int 0-32767 each read
$SECONDS    # seconds since shell started
$OLDPWD     # previous working directory (cd -)
$HOSTNAME   # hostname of the machine
$BASH_VERSION  # e.g. "5.2.15(1)-release"
```


!!! warning "$@ vs $*"
    Always use "$@" to forward arguments. "$*" merges all args into one string with IFS separator. $@ unquoted is the same as $* — word-splits. The only safe form is "$@".


!!! tip "BASH_SOURCE[0] vs $0"
    $0 is the script name when run directly, but the calling script name when sourced. ${BASH_SOURCE[0]} is always the current file even when sourced. Use it for SCRIPT_DIR detection.
