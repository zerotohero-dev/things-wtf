# fzf — Key Bindings & Actions

fzf's `--bind` option lets you attach any action (or chain of actions) to any key.

---

## Default Key Bindings

| Key | Action |
|-----|--------|
| `Enter` | Confirm selection |
| `Ctrl-C` / `Esc` | Abort |
| `↑` / `Ctrl-K` / `Ctrl-P` | Move cursor up |
| `↓` / `Ctrl-J` / `Ctrl-N` | Move cursor down |
| `Tab` | Toggle selection mark (multi-select mode) |
| `Shift-Tab` | Toggle selection and move up |
| `Ctrl-A` | Select all (if bound) |
| `Ctrl-D` | Deselect all (if bound) |
| `Page Up` / `Page Down` | Scroll page |
| `Home` / `End` | Jump to first/last item |
| `Ctrl-F` / `Ctrl-B` | Scroll preview page down/up (if bound) |
| `Alt-A` | Select all matching items |
| `Ctrl-R` | Toggle sort |
| `Ctrl-/` or `?` | Toggle preview (if bound) |

---

## --bind Syntax

```bash
--bind 'KEY:ACTION'
--bind 'KEY:ACTION1+ACTION2'        # chain multiple actions
--bind 'KEY1:ACTION,KEY2:ACTION'    # multiple bindings in one --bind
```

### Key Names

`ctrl-[a-z]`, `alt-[a-zA-Z]`, `f1`–`f12`, `enter`, `esc`, `tab`, `btab` (shift-tab), `space`, `bspace`, `up`, `down`, `left`, `right`, `home`, `end`, `pgup`, `pgdn`, `insert`, `delete`, `double-click`, `left-click`, `right-click`, `scroll-up`, `scroll-down`, `change` (query changed), `start`, `load`, `result` (result updated), `focus` (focus changed)

---

## Action Reference

### Navigation
| Action | Description |
|--------|-------------|
| `up` / `down` | Move cursor |
| `page-up` / `page-down` | Move by page |
| `half-page-up` / `half-page-down` | Move by half page |
| `first` / `last` | Jump to first/last item |
| `jump` | EasyMotion-style jump (requires `--jump-labels`) |
| `jump-accept` | Jump and accept in one action |

### Selection
| Action | Description |
|--------|-------------|
| `select` / `deselect` | Select/deselect current item |
| `toggle` | Toggle selection of current item |
| `select-all` / `deselect-all` | Select/deselect all |
| `toggle-all` | Toggle all selections |

### Preview
| Action | Description |
|--------|-------------|
| `toggle-preview` | Show/hide preview window |
| `toggle-preview-wrap` | Toggle line wrapping in preview |
| `preview-up` / `preview-down` | Scroll preview by one line |
| `preview-page-up` / `preview-page-down` | Scroll preview by page |
| `preview-half-page-up` / `preview-half-page-down` | Scroll by half page |
| `preview-top` / `preview-bottom` | Jump to top/bottom of preview |
| `change-preview(CMD)` | Change the preview command |
| `change-preview-window(OPTS)` | Cycle through window configurations |
| `refresh-preview` | Re-run the preview command |

### Input
| Action | Description |
|--------|-------------|
| `clear-query` | Clear the query string |
| `clear-screen` | Redraw the screen |
| `kill-line` | Delete from cursor to end of line |
| `kill-word` | Delete word before cursor |
| `unix-line-discard` | Delete from cursor to beginning |
| `unix-word-rubout` | Delete word before cursor (unix-style) |
| `yank` | Paste from kill buffer |
| `backward-delete-char` | Delete character before cursor |
| `delete-char` | Delete character at cursor |
| `backward-char` / `forward-char` | Move cursor left/right |
| `beginning-of-line` / `end-of-line` | Jump to start/end of query |
| `backward-word` / `forward-word` | Move by word |

### Execution
| Action | Description |
|--------|-------------|
| `execute(CMD)` | Run CMD with selected item; stay in fzf |
| `execute-silent(CMD)` | Run CMD without showing output |
| `become(CMD)` | Replace fzf process with CMD |
| `reload(CMD)` | Re-run CMD and refresh the list |
| `reload-sync(CMD)` | Like reload but waits for completion |

### Other
| Action | Description |
|--------|-------------|
| `accept` | Accept selection (like Enter) |
| `accept-non-empty` | Accept only if something is selected |
| `abort` | Quit without output |
| `print-query` | Print the query and exit |
| `replace-query` | Replace query with current item |
| `toggle-sort` | Toggle sort on/off |
| `toggle-search` | Enable/disable search |
| `offset-up` / `offset-down` | Scroll the view without moving cursor |
| `change-header(STR)` | Change the header text dynamically |
| `unbind(KEY)` | Remove a binding |
| `rebind(KEY)` | Restore a binding |

---

## Practical --bind Examples

```bash
# Open file in vim on enter, keep fzf open after
fzf --bind 'enter:execute(vim {})+reload(ls)'

# Copy path to clipboard (macOS pbcopy / Linux xclip)
fzf --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)'
fzf --bind 'ctrl-y:execute-silent(echo -n {} | xclip -selection clipboard)'

# Open with system default app
fzf --bind 'ctrl-o:execute-silent(xdg-open {})'

# Reload list after deleting a file
fzf --bind 'ctrl-x:execute(rm {})+reload(ls)'

# Toggle all and accept
fzf -m --bind 'ctrl-a:select-all+accept'

# Dynamic preview content based on query
fzf --preview 'grep -i {q} {} 2>/dev/null | head -20' \
    --bind 'change:refresh-preview'

# Cycle preview window layouts
fzf --preview 'cat {}' \
    --bind 'ctrl-/:change-preview-window(right:60%|down:40%|hidden|)'

# Become: replace fzf with the command (no subshell overhead)
fzf --bind 'enter:become(vim {})'

# Multiple actions chained with +
fzf --bind 'ctrl-r:toggle-sort+clear-screen'
```

---

!!! tip "execute vs execute-silent vs become"
    - `execute(CMD)` — runs CMD, shows its output, returns to fzf when done
    - `execute-silent(CMD)` — runs CMD in background, doesn't interrupt the UI
    - `become(CMD)` — replaces the fzf process entirely (like `exec`); most efficient for the "open in editor" pattern
