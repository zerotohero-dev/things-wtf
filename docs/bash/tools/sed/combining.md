# Combining sed, awk, and fzf

The three tools compose naturally in Unix pipelines. Each handles a different layer of the problem.

---

## The Pattern

```
source cmd  →  awk (shape)  →  sed (clean)  →  fzf (select)  →  awk (extract)  →  action cmd
```

| Stage | Role |
|-------|------|
| Source | `find`, `git`, `kubectl`, `grep`, `cat` |
| awk (shape) | Extract fields, filter rows, aggregate |
| sed (clean) | Strip noise, reformat strings |
| fzf (select) | Human picks one or more items |
| awk (extract) | Pull the relevant part from the selection |
| Action | `vim`, `kubectl`, `ssh`, `xargs` |

You won't always need all six stages, but the principle holds: **shape data before the human sees it, extract cleanly after they choose**.

---

## Pipeline Examples

### Select a pod to port-forward

```bash
kubectl get svc -A \
  | awk 'NR>1 {print $1"/"$2, $5}' \
  | sed 's|/TCP||g' \
  | fzf --header "NAMESPACE/NAME  PORTS" \
        --preview 'kubectl describe svc -n $(echo {1} | cut -d/ -f1) $(echo {1} | cut -d/ -f2)' \
  | awk '{print $1}' \
  | while IFS='/' read -r ns svc; do
      read -rp "Local port: " port
      kubectl port-forward -n "$ns" "svc/$svc" "${port}:${port}"
    done
```

---

### Find and jump to a TODO

```bash
grep -rn "TODO\|FIXME" . \
  | sed 's|^\./||' \
  | awk -F: '{print $1, $2, substr($0, index($0,$3))}' \
  | fzf --delimiter=' ' \
        --preview 'bat --color=always --highlight-line {2} {1}' \
        --preview-window='right:60%:+{2}+3/3' \
  | awk '{print "vim +" $2 " " $1}' \
  | bash
```

---

### Interactive log error explorer

```bash
cat app.log \
  | awk '/ERROR|WARN/ { printf "%5d  %-6s  %s\n", NR, $3, substr($0, index($0,$4)) }' \
  | fzf --header "LINE   LEVEL  MESSAGE" \
        --delimiter='  ' \
        --nth=3.. \
        --preview 'awk -v l={1} "NR>=l-5 && NR<=l+10" app.log | bat --color=always' \
        --preview-window=up:40%
```

---

### Helm values browser

```bash
helm show values "$CHART" \
  | awk '
      /^[a-zA-Z]/ { key = $0 }
      /^  [a-zA-Z]/ { print key " > " $0 }' \
  | sed 's/: /=/' \
  | fzf --prompt="Helm value: " \
  | awk -F'=' '{print "--set " $1 "=" $2}'
```

---

### Search and open a man page section

```bash
man -k . \
  | awk '{print $1 "(" $2 ")", $3, $4}' \
  | sed 's/)/):/' \
  | fzf --preview 'man {1} 2>/dev/null | head -40' \
        --preview-window=right:50% \
  | awk '{print $1}' \
  | sed 's/:.*//' \
  | xargs man
```

---

### Bulk replace in files selected interactively

```bash
# Select files to operate on, then sed them in-place
grep -rl "OLD_IMPORT" . \
  | fzf -m --preview 'grep --color=always -n "OLD_IMPORT" {}' \
  | xargs sed -i 's/OLD_IMPORT/NEW_IMPORT/g'
```

---

### Generate a kubectl exec command from a fuzzy pod picker

```bash
# awk extracts NS+POD, fzf selects, awk builds the command
kubectl get pods -A -o wide \
  | awk 'NR>1 { printf "%-20s %-40s %-10s %s\n", $1, $2, $4, $8 }' \
  | fzf --header "NAMESPACE            POD                                       STATUS     NODE" \
        --preview 'kubectl describe pod -n {1} {2}' \
        --preview-window=right:50% \
  | awk '{print "kubectl exec -it -n", $1, $2, "-- /bin/sh"}' \
  | bash
```

---

## Design Principles

### 1. Shape before displaying

Run `awk` first to extract only the columns fzf needs to show. A narrower display is easier to read and search.

```bash
# Bad: fzf sees all 12 kubectl columns
kubectl get pods -A | fzf

# Better: fzf sees only namespace, name, status
kubectl get pods -A | awk 'NR>1 {print $1, $2, $4}' | fzf
```

### 2. Clean noise before displaying

Use `sed` to strip units, prefixes, or decorators that would make fuzzy matching noisier.

```bash
git branch -a \
  | sed 's|remotes/origin/||; s/^[* ]*//' \
  | fzf
```

### 3. Extract minimally after selection

After `fzf`, use `awk` to pull out only the field your final command needs. Don't pass the whole line to `xargs` or `bash`.

```bash
# Bad: passes whole fzf output line
fzf | xargs kubectl delete pod

# Better: extract just the pod name from field 2
fzf | awk '{print $2}' | xargs kubectl delete pod -n "$NS"
```

### 4. Use --preview to give context

A preview command that runs `kubectl describe`, `git show`, `bat`, or `cat` dramatically reduces the number of false selections. The user picks confidently instead of guessing.

### 5. Use --header-lines for table data

When your source command already has a header row (like `kubectl get pods`), pass it through with `--header-lines=1` so fzf shows it as a sticky header without making it selectable.

```bash
kubectl get pods | fzf --header-lines=1
```
