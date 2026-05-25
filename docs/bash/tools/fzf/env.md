# fzf — Environment & Configuration

All fzf behavior can be configured through environment variables, making it easy to apply consistent defaults across all invocations.

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `FZF_DEFAULT_COMMAND` | Command to generate the initial list when no input is piped and no file argument given |
| `FZF_DEFAULT_OPTS` | Default options applied to **every** fzf invocation |
| `FZF_DEFAULT_OPTS_FILE` | Path to a file containing default options (one option per line or space-separated) |
| `FZF_CTRL_T_COMMAND` | Command for Ctrl-T file selection |
| `FZF_CTRL_T_OPTS` | Extra options for the Ctrl-T binding |
| `FZF_CTRL_R_OPTS` | Extra options for the Ctrl-R history search |
| `FZF_ALT_C_COMMAND` | Command for Alt-C directory selection |
| `FZF_ALT_C_OPTS` | Extra options for the Alt-C binding |
| `FZF_COMPLETION_TRIGGER` | Trigger string for fuzzy completion (default: `**`) |
| `FZF_COMPLETION_OPTS` | Extra options for `**` completion |
| `FZF_TMUX` | Set to `1` to use `fzf-tmux` wrapper by default |
| `FZF_TMUX_OPTS` | Options passed to `fzf-tmux` |

---

## Recommended Configuration

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# ── fzf default command ─────────────────────────────────────
# Use fd: respects .gitignore, shows hidden files, fast
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# ── fzf default options ──────────────────────────────────────
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border=rounded
  --info=inline
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-a:select-all'
  --bind 'ctrl-d:deselect-all'
  --bind 'ctrl-f:preview-page-down'
  --bind 'ctrl-b:preview-page-up'
  --color=bg+:#1e232e,bg:#0c0e13,spinner:#9b7de8,hl:#5ac8a0
  --color=fg:#c9d1e0,header:#5ac8a0,info:#f0a05a,pointer:#9b7de8
  --color=marker:#5ac8a0,fg+:#e8edf5,prompt:#9b7de8,hl+:#5ac8a0
  --color=border:#252b38
"

# ── Ctrl-T: file finder ──────────────────────────────────────
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --line-range=:100 {}'
  --preview-window=right:50%
  --bind 'ctrl-/:toggle-preview'"

# ── Ctrl-R: history search ───────────────────────────────────
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window=down:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color=header:italic
  --header='Ctrl-Y: copy command'"

# ── Alt-C: directory jump ────────────────────────────────────
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="
  --preview 'tree -C {} | head -30'
  --preview-window=right:50%"
```

---

## Options File

For large option sets, use a file:

```bash
export FZF_DEFAULT_OPTS_FILE="$HOME/.fzfrc"
```

`~/.fzfrc`:
```
--height=40%
--layout=reverse
--border=rounded
--color=bg+:#1e232e,fg:#c9d1e0
--bind ctrl-/:toggle-preview
--bind ctrl-a:select-all
```

Options in `FZF_DEFAULT_OPTS_FILE` are merged with `FZF_DEFAULT_OPTS`. Command-line options override both.

---

## Per-command Overrides

`FZF_DEFAULT_OPTS` applies everywhere, but you can override for specific invocations:

```bash
# Override height for this specific call
FZF_DEFAULT_OPTS="" fzf --height=90%

# Or just add the option at the end (last value wins for most options)
fzf --height=90%   # overrides the height set in FZF_DEFAULT_OPTS
```

---

## Checking the Effective Configuration

```bash
# See what fzf would do with current environment
fzf --bash | grep -A5 'CTRL_T'

# Print fzf version
fzf --version
```

---

## Using with tmux

```bash
# Drop-in tmux popup instead of inline
export FZF_TMUX=1
export FZF_TMUX_OPTS="-p 80%,60%"   # popup: 80% wide, 60% tall

# Or use fzf-tmux directly
git branch | fzf-tmux -p 60%
```
