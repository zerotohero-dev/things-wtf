# Traps & Signals


```bash title="trap signals for robust cleanup"
# trap 'action' SIGNAL [SIGNAL...]
# Common signals: EXIT INT TERM ERR HUP USR1 USR2 PIPE WINCH

# EXIT — always fires on script exit (clean or error)
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT     # quoted — expands at trigger time

# ERR — fires on any command with non-zero exit (respects -e)
trap 'echo "Error at line $LINENO: $BASH_COMMAND" >&2' ERR

# INT — Ctrl+C
trap 'echo "Interrupted"; exit 1' INT

# TERM — kill signal
trap 'echo "Terminated"; cleanup; exit 0' TERM

# Full production trap pattern
die() {
  echo "[FATAL] $* (line ${BASH_LINENO[0]})" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  local line="${BASH_LINENO[0]}"
  local cmd="$BASH_COMMAND"
  echo "[ERR] exit=$exit_code line=$line cmd='$cmd'" >&2
}

on_exit() {
  [[ -n "${TMPDIR_WORK:-}" ]] && rm -rf "$TMPDIR_WORK"
  [[ -f "${LOCKFILE:-}" ]] && rm -f "$LOCKFILE"
}

set -eE                          # -E makes ERR trap inherit to functions
trap on_error ERR
trap on_exit EXIT
trap 'die "interrupted"' INT TERM

# Reset trap to default
trap - ERR
# Ignore a signal
trap '' PIPE    # ignore SIGPIPE (common for long pipelines)

# USR1/USR2 for custom signals
trap 'reload_config' USR1         # send: kill -USR1 $pid
trap 'toggle_debug' USR2
```


!!! tip "Single quotes vs double quotes in trap"
    trap 'echo "$var"' EXIT — single quotes: $var expands when trap fires (late binding — gets current value at exit time). 
            trap "echo '$var'" EXIT — double quotes: $var expands when trap is called (early binding). Usually you want late binding — use single quotes.
