# fzf — Tool Integrations

fzf integrates cleanly with editors, version control, package managers, and container tools.

---

## Vim / Neovim

### fzf.vim plugin

Install `junegunn/fzf` and `junegunn/fzf.vim`. Commands available:

| Command | Description |
|---------|-------------|
| `:Files [PATH]` | Fuzzy-find files |
| `:GFiles` | Files tracked by git |
| `:GFiles?` | Git status (changed files) |
| `:Buffers` | Open buffers |
| `:Colors` | Color schemes |
| `:Ag [PATTERN]` | `ag` search results |
| `:Rg [PATTERN]` | `ripgrep` results (live) |
| `:Lines` | Lines in open buffers |
| `:BLines` | Lines in current buffer |
| `:Tags` | Tags in the project |
| `:BTags` | Tags in current buffer |
| `:Marks` | Marks |
| `:Jumps` | Jump list |
| `:History` | `v:oldfiles` + open buffers |
| `:History:` | Command history |
| `:History/` | Search history |
| `:Commits` | Git commits (requires fugitive) |
| `:BCommits` | Git commits for current buffer |
| `:Commands` | Vim commands |
| `:Maps` | Key mappings |
| `:Helptags` | Help tags |
| `:Filetypes` | File types |

```vim
" Recommended key mappings in .vimrc / init.vim
nnoremap <C-p> :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>rg :Rg<CR>
nnoremap <leader>/ :BLines<CR>
```

### Neovim: telescope.nvim

telescope.nvim is the dominant Neovim fuzzy finder. Uses the same concepts as fzf but is native Lua with a richer UI.

```lua
-- telescope keymaps (init.lua)
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<C-p>', builtin.find_files)
vim.keymap.set('n', '<leader>rg', builtin.live_grep)
vim.keymap.set('n', '<leader>b', builtin.buffers)
vim.keymap.set('n', '<leader>h', builtin.help_tags)
```

### Neovim: fzf-lua

fzf-lua is a fast, fzf-backed alternative to telescope. Uses the actual fzf binary.

```lua
require('fzf-lua').setup({ winopts = { height = 0.85, width = 0.80 } })
vim.keymap.set('n', '<C-p>', require('fzf-lua').files)
vim.keymap.set('n', '<leader>rg', require('fzf-lua').live_grep)
```

---

## Git

### Interactively stage hunks

```bash
git diff --name-only | fzf -m | xargs git add
```

### Cherry-pick from log

```bash
git log --oneline | fzf --preview 'git show {1}' \
  | awk '{print $1}' | xargs git cherry-pick
```

### Interactively restore a file to HEAD

```bash
git diff --name-only HEAD | fzf \
  --preview 'git diff --color=always HEAD -- {}' \
  | xargs git restore
```

### Browse tags

```bash
git tag | fzf --preview 'git show {}'
```

---

## tmux

### Select a tmux session to switch to

```bash
ftmux-session() {
  local session
  session=$(tmux list-sessions -F '#{session_name}' \
    | fzf --preview 'tmux list-windows -t {}' \
          --prompt="Session: ")
  [ -n "$session" ] && tmux switch-client -t "$session"
}
```

### Open a project in a new tmux window

```bash
fproject() {
  local dir
  dir=$(fd --type d --max-depth 3 . ~/projects ~/work 2>/dev/null \
    | fzf --preview 'ls {}' \
          --prompt="Project: ")
  [ -n "$dir" ] && tmux new-window -c "$dir" -n "$(basename "$dir")"
}
```

### fzf inside a tmux popup

```bash
# Any fzf command can be wrapped in a tmux popup
git branch | fzf-tmux -p 60%,40% --preview 'git log --oneline {-1}'
```

---

## Package Managers

### Homebrew — install formula interactively

```bash
brew install $(brew search | fzf --preview 'brew info {}')
```

### Homebrew — uninstall interactively

```bash
brew uninstall $(brew list | fzf -m --preview 'brew info {}')
```

### Homebrew — install cask

```bash
brew install --cask $(brew search --casks | fzf --preview 'brew info --cask {}')
```

### apt / dnf — install interactively

```bash
# apt
apt-cache search '' | fzf | awk '{print $1}' | xargs sudo apt install -y

# dnf
dnf list available 2>/dev/null | fzf | awk '{print $1}' | xargs sudo dnf install -y
```

---

## ripgrep

### Live grep with fzf (see also fzf recipes)

```bash
rg --color=always --line-number '' \
  | fzf --ansi --delimiter=: \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window='right:60%:+{2}+3/3' \
        --bind 'enter:execute(vim +{2} {1})'
```

---

## SPIRE / Kubernetes (VKS)

```bash
# Select a SPIFFE SVID workload
fsvid() {
  local entry
  entry=$(spire-server entry show -output json 2>/dev/null \
    | jq -r '.entries[] | "\(.id.value)\t\(.spiffe_id.value)"' \
    | fzf --delimiter='\t' --with-nth=2 \
          --preview 'spire-server entry show -entryID {1} 2>/dev/null | jq .')
  [ -n "$entry" ] && echo "$entry" | awk '{print $1}'
}
```
