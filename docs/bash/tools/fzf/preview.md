# fzf — Preview Window

The preview window runs a shell command for each highlighted item and shows the output in a side pane — in real time as you move through the list. It's one of fzf's most powerful features.

---

## Basic Usage

```bash
# Preview file content (cat fallback if bat not available)
fzf --preview 'bat --color=always {} 2>/dev/null || cat {}'

# Preview directory listing
find . -type d | fzf --preview 'ls -la {}'

# Preview git log for each branch
git branch | fzf --preview 'git log --oneline --color=always {-1} | head -20'
```

---

## Preview Placeholders

| Placeholder | Expands to |
|-------------|-----------|
| `{}` | The current line (full text of highlighted item) |
| `{1}`, `{2}`, … | Field N (using `--delimiter`) |
| `{-1}` | Last field |
| `{1..3}` | Fields 1 through 3 |
| `{2..}` | From field 2 to last |
| `{..3}` | From first field to field 3 |
| `{q}` | Current query string |
| `{n}` | Zero-indexed line number of the item in the list |
| `{+}` | All selected items (space-separated, multi-select) |
| `{+1}` | Field 1 of all selected items |

---

## Window Position and Size

```bash
# Right side, 60% wide (default)
fzf --preview 'cat {}' --preview-window=right:60%

# Top, 40% height
fzf --preview 'cat {}' --preview-window=up:40%

# Bottom, 20 lines, word-wrap
fzf --preview 'cat {}' --preview-window=bottom:20:wrap

# Left side, no border
fzf --preview 'cat {}' --preview-window=left:40%:noborder

# Hidden by default (toggle with a key)
fzf --preview 'cat {}' --preview-window=hidden \
    --bind '?:toggle-preview'
```

### Size format

`[POSITION][:SIZE][:OPTS]` where:
- **POSITION**: `up`, `down`, `left`, `right` (default: `right`)
- **SIZE**: N lines or N% of terminal
- **OPTS**: `wrap`, `border`, `noborder`, `follow`, `cycle`, `hidden`, `nofollow`

---

## Scrolling the Preview

```bash
# Auto-scroll to bottom (useful for logs)
fzf --preview 'tail -50 {}' --preview-window=follow

# Key bindings to scroll manually
fzf --preview 'cat {}' \
    --bind 'ctrl-f:preview-page-down' \
    --bind 'ctrl-b:preview-page-up' \
    --bind 'ctrl-u:preview-half-page-up' \
    --bind 'ctrl-d:preview-half-page-down'
```

---

## Toggle and Cycle Preview Size

```bash
# Toggle preview on/off
fzf --preview 'cat {}' --bind '?:toggle-preview'

# Cycle through sizes
fzf --preview 'cat {}' \
    --bind 'ctrl-/:change-preview-window(right:60%|down:40%|hidden|)'
```

---

## Syntax-Highlighted File Preview

```bash
# With bat (best option)
fzf --preview 'bat --color=always --style=numbers --line-range=:200 {}'

# With highlight
fzf --preview 'highlight -O ansi {} 2>/dev/null || cat {}'

# With cat (POSIX fallback)
fzf --preview 'cat {}'
```

---

## Preview With Line Context (Grep Results)

```bash
# grep -n output: FILE:LINE:CONTENT
grep -rn "TODO" . | fzf \
  --delimiter=: \
  --preview 'bat --color=always --highlight-line {2} {1}' \
  --preview-window 'right:60%:+{2}+3/3'

# The +{2}+3/3 scroll expression means:
#   Start at line {2} (the match), offset by 3, using 1/3 of preview height as context
```

---

## Dynamic Preview Based on File Type

```bash
fzf --preview '
  file={};
  case "$file" in
    *.json) jq . "$file" ;;
    *.yaml|*.yml) cat "$file" ;;
    *.png|*.jpg) echo "[image: $file]" ;;
    *) bat --color=always "$file" 2>/dev/null || cat "$file" ;;
  esac
'
```

---

## Preview With the Current Query

```bash
# Show grep results for the current query in the preview
fzf --preview 'grep --color=always -i {q} {} 2>/dev/null | head -20' \
    --bind 'change:reload(find . -type f)'
```

---

## Live Grep with Reload (rg + fzf)

```bash
# Start with search disabled; reload rg on every keystroke
fzf --disabled --ansi \
    --bind 'start:reload:rg --color=always --line-number "" .' \
    --bind 'change:reload:rg --color=always --line-number {q} . || true' \
    --delimiter=: \
    --preview 'bat --color=always --highlight-line {2} {1}' \
    --preview-window 'right:60%:+{2}+3/3' \
    --bind 'enter:execute(vim +{2} {1})'
```

---

!!! tip "Performance"
    Preview commands run in a subshell on every cursor move. For expensive operations, add a short delay with `--preview-window=...:~3` (show first 3 lines as a placeholder while command runs), or gate expensive commands behind a key binding using `execute` instead of `--preview`.
