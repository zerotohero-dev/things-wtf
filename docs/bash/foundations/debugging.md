# Debugging


```bash title="debugging techniques"
# Lint/syntax check — never executes
bash -n script.sh

# Trace execution
bash -x script.sh
set -x         # enable mid-script
set +x         # disable mid-script

# Verbose — show lines as read (before expansion)
bash -v script.sh
set -v

# Custom PS4 — richer trace output
export PS4='+[${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-}] '
set -x

# Debug specific section only
{
  set -x
  suspicious_command
  set +x
} 2>&1   # redirect trace to stdout for piping/capturing

# Inspect variable
declare -p varname         # print type + value
declare -p myarray        # shows array contents properly

# Print call stack
for i in "${!FUNCNAME[@]}"; do
  echo "  $i: ${FUNCNAME[$i]} (${BASH_SOURCE[$i+1]:-main}:${BASH_LINENO[$i]})"
done

# shellcheck — static analysis (install separately)
shellcheck script.sh
shellcheck -e SC2046 script.sh  # exclude specific warning

# bashdb — GNU bash debugger (install separately)
bashdb script.sh
```
