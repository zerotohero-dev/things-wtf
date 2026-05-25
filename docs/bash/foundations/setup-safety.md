# Setup & Safety

> **always do this**

Every non-trivial script should start with the same boilerplate. Missing these means silent failures, undefined variables silently expanding to empty, and debugging nightmares at 3am.


```bash title="canonical script header"
#!/usr/bin/env bash
# Use /usr/bin/env to find bash in PATH (portable across systems)
# NOT #!/bin/bash — that path isn't guaranteed everywhere

set -e          # exit immediately if a command fails (errexit)
set -u          # treat unset variables as errors (nounset)
set -o pipefail  # catch failures in pipes (exit code = last failure)
set -E          # ERR trap is inherited by functions/subshells

# One-liner version — commonly seen in prod scripts:
set -euo pipefail

# Useful debug option (enable when diagnosing):
set -x          # print each command before executing (xtrace)
set +x          # turn it off
```


!!! danger "Why pipefail matters"
    Without pipefail: cat nosuchfile | grep foo | wc -l exits 0 even though cat failed. The exit code of a pipeline is the last command's exit code by default.


!!! warning "-e gotcha with subshells"
    set -e does NOT trigger when a failing command is part of an if, while, until, or ||/&& chain — those are "checked" contexts. Also does not propagate into subshells unless you add -E.


```bash title="full production header with cleanup trap"
#!/usr/bin/env bash
set -euo pipefail

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"

# Temp file cleanup on any exit
TMPDIR_WORK=""
cleanup() {
  if [[ -n "$TMPDIR_WORK" ]] && [[ -d "$TMPDIR_WORK" ]]; then
    rm -rf "$TMPDIR_WORK"
  fi
}
trap cleanup EXIT

# Now safe to create temp files
TMPDIR_WORK="$(mktemp -d)"
```


| Flag | Long form | Effect |
| --- | --- | --- |
| -e | errexit | Exit on first error (with exceptions) |
| -u | nounset | Unset variable reference = error |
| -o pipefail | – | Pipeline exit code = rightmost failure |
| -E | errtrace | ERR trap inherits into functions |
| -x | xtrace | Print commands as executed |
| -n | noexec | Parse only, don't execute (dry-run lint) |
| -f | noglob | Disable filename expansion (globbing) |
| -C | noclobber | Refuse to overwrite files with > |
