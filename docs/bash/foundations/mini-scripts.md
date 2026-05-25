# Mini Scripts

Drop-in utility functions for common script needs.


## lockfile.sh

prevent concurrent execution

```bash
LOCKFILE="/var/run/${SCRIPT_NAME}.lock"
acquire_lock() {
  if ! mkdir "$LOCKFILE" 2>/dev/null; then
    local pid
    pid=$(cat "$LOCKFILE/pid" 2>/dev/null || echo "?")
    die "Already running (PID: $pid). Remove $LOCKFILE if stale."
  fi
  echo "$$" > "$LOCKFILE/pid"
  trap 'rm -rf "$LOCKFILE"' EXIT
}
acquire_lock
```


## retry.sh

retry with exponential backoff

```bash
retry() {
  local -i attempts="${RETRY_ATTEMPTS:-5}"
  local -i delay="${RETRY_DELAY:-1}"
  local -i i=0
  until "$@"; do
    ((++i))
    [[ $i -ge $attempts ]] && { echo "Failed after $i attempts: $*" >&2; return 1; }
    echo "Attempt $i/$attempts failed. Retrying in ${delay}s..." >&2
    sleep "$delay"
    delay=$(( delay * 2 ))
  done
}
# Usage:
retry curl -sf "https://api.example.com/health"
RETRY_ATTEMPTS=10 RETRY_DELAY=2 retry kubectl rollout status deploy/app
```


## log.sh

timestamped colored logging

```bash
# Colors (auto-disabled if not a terminal)
if [[ -t 2 ]]; then
  RED='\033[0;31m' YELLOW='\033[0;33m' GREEN='\033[0;32m'
  BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' YELLOW='' GREEN='' BLUE='' NC=''
fi
_ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log_info()  { echo -e "$(_ts) ${GREEN}INFO${NC}  $*" >&2; }
log_warn()  { echo -e "$(_ts) ${YELLOW}WARN${NC}  $*" >&2; }
log_error() { echo -e "$(_ts) ${RED}ERROR${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] || return 0; echo -e "$(_ts) ${BLUE}DEBUG${NC} $*" >&2; }
die()       { log_error "$*"; exit 1; }
# Usage: log_info "Starting..." ; log_warn "Low disk" ; die "Fatal error"
```


## wait_for.sh

wait for TCP port / URL / condition

```bash
wait_for_port() {
  local host="$1" port="$2" timeout="${3:-60}"
  local -i elapsed=0
  echo "Waiting for $host:$port..."
  until nc -z "$host" "$port" 2>/dev/null; do
    ((elapsed++))
    [[ $elapsed -ge $timeout ]] && die "Timeout waiting for $host:$port"
    sleep 1
  done
  echo "$host:$port is ready (${elapsed}s)"
}

wait_for_url() {
  local url="$1" timeout="${2:-60}"
  local -i elapsed=0
  until curl -sf --max-time 2 "$url" > /dev/null; do
    ((elapsed++))
    [[ $elapsed -ge $timeout ]] && die "Timeout waiting for $url"
    sleep 1
  done
  echo "$url ready (${elapsed}s)"
}
# Usage:
wait_for_port postgres 5432 120
wait_for_url "http://localhost:8080/health"
```


## progress.sh

spinner for long-running commands

```bash
spinner() {
  local pid="$1" msg="${2:-Working}"
  local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  while kill -0 "$pid" 2>/dev/null; do
    for ((i=0; i<${#chars}; i++)); do
      printf '\r %s %s' "${chars:$i:1}" "$msg" >&2
      sleep 0.1
      kill -0 "$pid" 2>/dev/null || break
    done
  done
  printf '\r' >&2
}
# Usage:
long_command &
spinner $! "Deploying..."
wait $!
```


## semaphore.sh

limit parallel job concurrency

```bash
# Run at most N jobs in parallel
MAX_JOBS=4
pids=()

wait_for_slot() {
  while [[ "${#pids[@]}" -ge $MAX_JOBS ]]; do
    wait -n 2>/dev/null || true  # bash 4.3+
    # Reap finished pids
    new_pids=()
    for p in "${pids[@]}"; do
      kill -0 "$p" 2>/dev/null && new_pids+=($p)
    done
    pids=("${new_pids[@]}")
  done
}

for item in "${items[@]}"; do
  wait_for_slot
  process "$item" &
  pids+=($!)
done
wait   # wait for remaining jobs
```


## config_parser.sh

parse key=value config files

```bash
load_config() {
  local file="$1"
  [[ -f "$file" ]] || die "Config not found: $file"
  while IFS='=' read -r key val; do
    # Skip blanks and comments
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${key// /}" ]] && continue
    # Strip whitespace, quotes
    key="${key#"${key%%[! ]*}"}"   # ltrim
    key="${key%"${key##*[! ]}"}"   # rtrim
    val="${val#\"}"; val="${val%\"}"  # unquote
    declare -g "$key=$val"        # set in global scope
  done < "$file"
}
# file: app.conf
# PORT=8080
# HOST=localhost
load_config app.conf
echo "$PORT"  # 8080
```


## backup.sh

rotating backups with date suffix

```bash
backup_rotate() {
  local src="$1" dest_dir="$2" keep="${3:-7}"
  local ts=$(date '+%Y%m%d_%H%M%S')
  local name="$(basename "$src")"
  mkdir -p "$dest_dir"
  cp -a "$src" "${dest_dir}/${name}.${ts}"
  # Delete old backups, keep only N most recent
  ls -t "${dest_dir}/${name}."* 2>/dev/null | tail -n "+$((keep+1))" |
    xargs -r rm -rf
  echo "Backed up: ${dest_dir}/${name}.${ts} (kept latest $keep)"
}
backup_rotate /etc/nginx /backups/nginx 14
```


## tmpdir.sh

safe temp directory with auto-cleanup

```bash
WORK_DIR=""
trap '[[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"' EXIT
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/myscript.XXXXXX")
# WORK_DIR is now safe to use and will be cleaned up on exit
cp important_file "$WORK_DIR/"
cd "$WORK_DIR"
# do work...
```
