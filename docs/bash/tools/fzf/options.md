# fzf — Key Options

All options can be set on the command line or in `FZF_DEFAULT_OPTS`.

---

## Layout & Appearance

| Option | Description |
|--------|-------------|
| `--height=N[%]` | Show fzf inline at N rows or N% of terminal height instead of fullscreen |
| `--min-height=N` | Minimum height when using percentage |
| `--layout=LAYOUT` | `default` (bottom-up), `reverse` (top-down), `reverse-list` |
| `--border[=STYLE]` | Draw a border. Styles: `rounded`, `sharp`, `bold`, `double`, `horizontal`, `vertical`, `top`, `bottom`, `left`, `right`, `none` |
| `--border-label=STR` | Label text displayed in the border |
| `--border-label-pos=N` | Position of border label (positive = from left, negative = from right) |
| `--margin=TRBL` | Margin around the fzf window (e.g., `1,2`) |
| `--padding=TRBL` | Inner padding |
| `--info=STYLE` | Display style for match count: `default`, `right`, `hidden`, `inline` |
| `--separator=STR` | Separator between the header and the list |
| `--scrollbar[=C]` | Scrollbar character |
| `--color=OPTS` | Customize colors (see below) |

---

## Prompt & Header

| Option | Description |
|--------|-------------|
| `--prompt=STR` | Input prompt string (default: `> `) |
| `--pointer=STR` | Character for the current item (default: `>`) |
| `--marker=STR` | Character for selected items in multi-select (default: `>`) |
| `--header=STR` | Static header text shown above the list |
| `--header-lines=N` | Treat first N lines of input as a sticky, non-filterable header |
| `--header-first` | Show header before the prompt |

---

## Input & Output

| Option | Description |
|--------|-------------|
| `-m`, `--multi` | Enable multi-select (Tab = toggle, Enter = confirm all) |
| `--no-multi` | Disable multi-select (default) |
| `--query=STR` | Start with this initial query |
| `-1`, `--select-1` | If only one match, auto-select without showing UI |
| `-0`, `--exit-0` | Exit immediately with no output if no match |
| `--filter=STR` | Non-interactive filter mode: just output matches and exit |
| `--print-query` | Print the query string as the first line of output |
| `--expect=KEYS` | Print the key used to exit as first line (`ctrl-v`, `enter`, etc.) |
| `--read0` | Read null-delimited input (for filenames with spaces/newlines) |
| `--print0` | Output null-delimited results |
| `--no-sort` | Don't sort results; preserve input order |
| `--tac` | Reverse the input before displaying |
| `--sync` | Wait until all input is read before displaying |
| `--tail=N` | Only display the last N items |

---

## Field Handling

| Option | Description |
|--------|-------------|
| `--delimiter=STR` | Field delimiter for `--nth` and `--with-nth` (string or regex) |
| `--nth=FIELDS` | Comma-separated list of fields to search. Use `-1` for last field. |
| `--with-nth=FIELDS` | Display only these fields (full line still stored internally) |
| `--ansi` | Parse ANSI color codes in input and render them |

```bash
# Search only filename (last component of a path)
find . -type f | fzf --delimiter=/ --nth=-1

# Show only filename, but pass full path downstream
find . -type f | fzf --delimiter=/ --with-nth=-1

# Parse colored output
ls --color=always | fzf --ansi
```

---

## Search Behavior

| Option | Description |
|--------|-------------|
| `-i`, `--ignore-case` | Case-insensitive matching |
| `+i`, `--no-ignore-case` | Case-sensitive matching |
| `--exact` | Use exact matching by default (no fuzzy) |
| `+x`, `--no-extended` | Disable extended search (fuzzy only) |
| `--algo=TYPE` | Scoring algorithm: `v1` (fast) or `v2` (default, accurate) |
| `--disabled` | Start with search disabled (useful with dynamic `reload`) |
| `--keep-right` | Keep the right side of long lines visible in the list |
| `--filepath-word` | Make word-wise actions (`alt-b`, `alt-f`) respect path separators |

---

## Practical Option Combinations

```bash
# Quick picker: inline, no fullscreen
fzf --height=40% --layout=reverse --border=rounded

# kubectl-style: show header, search everything
kubectl get pods | fzf --header-lines=1 --height=50%

# File picker with preview and copy-path binding
fzf --preview 'bat --color=always {}' \
    --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)' \
    --header 'Ctrl-Y: copy path'

# Non-interactive filter (use in scripts like grep)
fzf --filter="pattern" < list.txt

# Multi-select with select-all binding
fzf -m --bind 'ctrl-a:select-all,ctrl-d:deselect-all'

# Pass a key to detect how user exited
result=$(fzf --expect=ctrl-v,ctrl-x,enter)
key=$(head -1 <<< "$result")
sel=$(tail -1 <<< "$result")
case "$key" in
  ctrl-v) vim "$sel" ;;
  ctrl-x) xdg-open "$sel" ;;
  *)      echo "$sel" ;;
esac
```

---

## Color Customization

```bash
# Format: --color=COMPONENT:ANSI_CODE,...
# or use named themes: dark, light, 16, bw

# Components: fg, bg, hl (match highlight), fg+, bg+, hl+,
#   info, border, prompt, pointer, marker, spinner, header, label

fzf --color='bg:#0c0e13,bg+:#1e232e,fg:#c9d1e0,fg+:#e8edf5'  \
    --color='hl:#5ac8a0,hl+:#5ac8a0,info:#f0a05a,prompt:#9b7de8' \
    --color='pointer:#9b7de8,marker:#5ac8a0,border:#252b38'
```
