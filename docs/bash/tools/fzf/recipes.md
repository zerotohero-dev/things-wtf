# fzf — Practical Recipes

Shell functions you can drop straight into `~/.bashrc` or `~/.zshrc`. Each one is self-contained.

---

## Git

### Interactive branch checkout

```bash
fbr() {
  local branch
  branch=$(git branch -a \
    | grep -v HEAD \
    | sed 's/^[* ]*//' \
    | fzf --preview "git log --oneline --color=always {-1} | head -20" \
          --preview-window=right:50% \
          --prompt="Branch: ")
  [ -n "$branch" ] && git checkout "${branch#remotes/origin/}"
}
```

### Interactive git log browser

```bash
fgl() {
  git log --oneline --color=always "$@" \
    | fzf --ansi --no-sort --reverse \
          --preview 'git show --color=always {1}' \
          --preview-window=right:60% \
          --bind 'enter:execute(git show --color=always {1} | less -R)' \
          --bind 'ctrl-y:execute-silent(echo {1} | pbcopy)' \
          --header='Enter: show diff  Ctrl-Y: copy hash'
}
```

### Interactive git stash apply

```bash
fstash() {
  local stash
  stash=$(git stash list \
    | fzf --preview 'git stash show -p {1}' \
          --preview-window=right:60%)
  [ -n "$stash" ] && git stash apply "${stash%%:*}"
}
```

### Interactively stage files

```bash
fadd() {
  local files
  files=$(git diff --name-only HEAD \
    | fzf -m \
          --preview 'git diff --color=always HEAD -- {}' \
          --preview-window=right:60%)
  [ -n "$files" ] && echo "$files" | xargs git add
}
```

### Checkout a file from a specific commit

```bash
fco() {
  local commit file
  commit=$(git log --oneline | fzf --preview 'git show {1}' | awk '{print $1}')
  file=$(git show --stat "$commit" | grep '|' | awk '{print $1}' \
    | fzf --preview "git show $commit -- {}")
  [ -n "$file" ] && git checkout "$commit" -- "$file"
}
```

---

## Process Management

### Kill a process interactively

```bash
fkill() {
  local pid
  pid=$(ps aux \
    | fzf --header-lines=1 \
          --preview 'echo {}' \
          --preview-window=down:3:wrap \
          --prompt="Kill: " \
    | awk '{print $2}')
  [ -n "$pid" ] && kill -"${1:-9}" "$pid"
}
```

### Interactive lsof port checker

```bash
fport() {
  local entry
  entry=$(sudo lsof -iTCP -sTCP:LISTEN -P \
    | fzf --header-lines=1 \
          --prompt="Port: ")
  [ -n "$entry" ] && echo "$entry" | awk '{print $2}' | xargs kill -9
}
```

---

## File Operations

### Open recent files (from shell history patterns)

```bash
fhist() {
  local file
  file=$(history \
    | grep -oE '[^ ]+\.(go|yaml|md|sh|py|json|tf)' \
    | sort -u \
    | fzf --preview 'bat --color=always {} 2>/dev/null' \
          --preview-window=right:60%)
  [ -n "$file" ] && ${EDITOR:-vim} "$file"
}
```

### Copy file path(s) to clipboard

```bash
fcopy() {
  fzf -m \
    --preview 'bat --color=always {}' \
    --preview-window=right:50% \
  | tr '\n' ' ' | pbcopy   # macOS; replace pbcopy with xclip -sel clip for Linux
}
```

---

## Docker

### Interactive container exec

```bash
dexec() {
  local ctr shell="${1:-/bin/sh}"
  ctr=$(docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' \
    | fzf --header='NAME    IMAGE    STATUS' \
          --preview 'docker inspect {1} | jq .[0].Config' \
          --delimiter='\t' \
          --with-nth=1,2,3 \
    | awk '{print $1}')
  [ -n "$ctr" ] && docker exec -it "$ctr" "$shell"
}
```

### Interactive image removal

```bash
drmi() {
  docker images \
    | fzf -m --header-lines=1 \
          --preview 'docker inspect {3}' \
    | awk '{print $3}' \
    | xargs docker rmi
}
```

### Tail container logs

```bash
dlogs() {
  local ctr
  ctr=$(docker ps --format '{{.Names}}' | fzf --prompt="Container: ")
  [ -n "$ctr" ] && docker logs -f "$ctr"
}
```

---

## Kubernetes

### Interactive pod log viewer

```bash
klogs() {
  local ns pod
  ns=$(kubectl get ns -o name | cut -d/ -f2 \
    | fzf --prompt="Namespace: " --preview 'kubectl get pods -n {}')
  [ -z "$ns" ] && return
  pod=$(kubectl get pods -n "$ns" -o name | cut -d/ -f2 \
    | fzf --prompt="Pod: " \
          --preview "kubectl describe pod -n $ns {}")
  [ -n "$pod" ] && kubectl logs -f -n "$ns" "$pod"
}
```

### Interactive pod exec

```bash
kexec() {
  local ns pod shell="${1:-/bin/sh}"
  ns=$(kubectl get ns -o name | cut -d/ -f2 | fzf --prompt="Namespace: ")
  [ -z "$ns" ] && return
  pod=$(kubectl get pods -n "$ns" -o name | cut -d/ -f2 \
    | fzf --prompt="Pod: " \
          --preview "kubectl describe pod -n $ns {}")
  [ -n "$pod" ] && kubectl exec -it -n "$ns" "$pod" -- "$shell"
}
```

### Port-forward to a service

```bash
kpf() {
  local entry ns svc port
  entry=$(kubectl get svc -A \
    | fzf --header-lines=1 \
          --preview 'kubectl describe svc -n {1} {2}')
  [ -z "$entry" ] && return
  ns=$(echo "$entry" | awk '{print $1}')
  svc=$(echo "$entry" | awk '{print $2}')
  read -rp "Local port: " port
  kubectl port-forward -n "$ns" "svc/$svc" "${port}:${port}"
}
```

---

## SSH

### Pick a host from ~/.ssh/config

```bash
fssh() {
  local host
  host=$(grep -E '^Host [^*]' ~/.ssh/config \
    | awk '{print $2}' \
    | fzf --prompt="SSH: " \
          --preview 'grep -A10 "^Host {}" ~/.ssh/config')
  [ -n "$host" ] && ssh "$host"
}
```

---

## Interactive Live Grep (ripgrep + fzf)

The most powerful recipe: a live search that updates as you type, with file preview.

```bash
rgi() {
  local initial_query="${*:-}"
  : | fzf \
    --disabled \
    --ansi \
    --query "$initial_query" \
    --bind "start:reload:rg --color=always --line-number --no-heading -- {q} . || true" \
    --bind "change:reload:rg --color=always --line-number --no-heading -- {q} . || true" \
    --bind 'enter:execute(vim +{1} {2..})' \
    --delimiter=: \
    --preview 'bat --color=always {2} --highlight-line {1}' \
    --preview-window 'right:60%:+{1}+3/3' \
    --prompt='Search: '
}
```

Usage: `rgi` or `rgi "initial search term"`
