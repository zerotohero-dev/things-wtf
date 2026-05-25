# fzf — Shell Integration

fzf's shell integration installs several key bindings and a fuzzy completion trigger. Enable it once in your shell config and you'll wonder how you lived without it.

---

## Enable Integration

```bash
# ~/.bashrc
eval "$(fzf --bash)"

# ~/.zshrc
eval "$(fzf --zsh)"

# ~/.config/fish/config.fish
fzf --fish | source
```

---

## Built-in Key Bindings

### Ctrl-T — Paste Selected Files

Invokes `find` (or `FZF_CTRL_T_COMMAND`) and pastes the selected path(s) at the cursor.

```bash
# Type a command, then press Ctrl-T to insert a file path
vim <Ctrl-T>            # select a file to open
git add <Ctrl-T>        # select files to stage
cp <Ctrl-T> /dest/      # select source file
```

### Ctrl-R — Interactive History Search

Replaces the default `Ctrl-R` reverse-incremental-search with fzf. Much faster and shows context.

```bash
# Press Ctrl-R at any prompt
# Type to fuzzy-search your shell history
# Enter to execute, or Ctrl-C to paste without executing (bash/zsh differ)
```

### Alt-C — Fuzzy cd

Invokes `find` (or `FZF_ALT_C_COMMAND`) to select a directory, then `cd`s into it.

```bash
# Press Alt-C at any prompt
# Type to fuzzy-search subdirectories
# Enter to cd into the selected directory
```

---

## Fuzzy Completion with **

Type `**` followed by Tab to trigger fzf completion for the current command.

```bash
vim **<Tab>             # select a file to open
cd **<Tab>              # select a directory
kill -9 **<Tab>         # select a process ID
ssh **<Tab>             # select a host from ~/.ssh/config
unset **<Tab>           # select an environment variable to unset
export **<Tab>          # select an environment variable
```

The trigger string is configurable:

```bash
export FZF_COMPLETION_TRIGGER='~~'   # use ~~ instead of **
```

---

## Customizing Shell Bindings

All bindings are controlled via environment variables. Put these in `~/.bashrc` or `~/.zshrc`.

### Ctrl-T customization

```bash
# Use fd instead of find (respects .gitignore, faster)
export FZF_CTRL_T_COMMAND="fd --type f --hidden --follow --exclude .git"

# Add preview to Ctrl-T
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --line-range=:50 {}'
  --bind 'ctrl-/:toggle-preview'
  --border=rounded"
```

### Ctrl-R customization

```bash
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Ctrl-Y: copy to clipboard'"
```

### Alt-C customization

```bash
# Use fd for directory search
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# Show tree preview
export FZF_ALT_C_OPTS="
  --preview 'tree -C {} | head -50'
  --border=rounded"
```

---

## Custom Completion for Specific Commands

Define `_fzf_comprun` to provide custom fzf options per command:

```bash
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'tree -C {} | head -30' "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}" "$@" ;;
    ssh)          fzf --preview 'dig {}' "$@" ;;
    *)            fzf --preview 'bat --color=always {} 2>/dev/null || ls {}' "$@" ;;
  esac
}
```

---

## Custom Path and Directory Generators

Override `_fzf_compgen_path` and `_fzf_compgen_dir` to change what appears in `**` completion:

```bash
# Use fd for both path and directory completion
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}
```

---

## Disabling Specific Bindings

```bash
# Disable Alt-C (if it conflicts with another binding)
export FZF_ALT_C_COMMAND=""

# Or bind it to something else
bindkey -r '\ec'    # zsh: remove the binding entirely
```

---

!!! tip "zsh widget conflicts"
    On zsh, if `Ctrl-T` or `Alt-C` don't work, check `bindkey | grep fzf` and `bindkey | grep ctrl`. Some plugin frameworks (oh-my-zsh, antidote) bind these keys themselves. The fzf shell integration must be sourced *after* those frameworks.
