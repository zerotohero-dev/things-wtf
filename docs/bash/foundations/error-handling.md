# Error Handling Patterns


```bash title="battle-tested error patterns"
# die function — standard error exit
die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }
info() { echo "INFO: $*"; }

# require — assert precondition
require_cmd() {
  command -v "$1" &> /dev/null || die "Required command not found: $1"
}
require_cmd kubectl
require_cmd jq
require_cmd helm

# require_var — assert variable is set and non-empty
require_var() {
  [[ -n "${!1:-}" ]] || die "Required variable not set: $1"
}
require_var KUBECONFIG
require_var VAULT_ADDR

# retry with backoff
retry() {
  local -i max="${1:-3}"; shift
  local -i delay="${1:-2}"; shift
  local -i attempt=0
  until "$@"; do
    ((++attempt))
    [[ $attempt -ge $max ]] && die "$* failed after $max attempts"
    warn "Attempt $attempt failed; retrying in ${delay}s"
    sleep "$delay"
    delay=$(( delay * 2 ))   # exponential backoff
  done
}
retry 5 1 curl -sf "$url"  # retry up to 5 times, starting 1s delay

# run_or_die — execute and fail loudly
run() {
  echo "+ $*" >&2    # log command
  "$@"             # execute
}

# Suppress error for optional commands
some_optional_cmd || true     # ignore failure
some_optional_cmd || :        # same — : is the null command (always succeeds)

# Conditional default values (parameter expansion)
port="${PORT:-8080}"          # use $PORT if set, else 8080
host="${HOST:?'HOST must be set'}"  # error and exit if unset
```
