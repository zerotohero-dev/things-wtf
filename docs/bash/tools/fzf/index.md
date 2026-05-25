# fzf — Fuzzy Finder

> fzf is a general-purpose command-line fuzzy finder. It reads a list from stdin, displays an interactive full-screen selector UI, and writes the selection to stdout.

It's written in Go, has zero runtime dependencies, and is fast enough to filter millions of lines interactively.

---

## How fzf Works

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  stdin (any list)  →  fzf UI  →  stdout (selection)         │
│                                                              │
│  1. Read all lines from stdin                                │
│  2. Display interactive filter UI                            │
│  3. User types to narrow the list                            │
│  4. User presses Enter (or a bound key)                      │
│  5. Selected line(s) written to stdout                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

fzf is **not** limited to files. Any list works: git branches, process IDs, docker containers, kubectl resources, history entries, or lines from any command.

---

## Installation

```bash
# macOS
brew install fzf

# Fedora / RHEL
sudo dnf install fzf

# Debian / Ubuntu
sudo apt install fzf

# From source (any platform)
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

### Shell Integration

Add to `~/.bashrc` or `~/.zshrc`:

```bash
eval "$(fzf --bash)"   # bash
eval "$(fzf --zsh)"    # zsh
source /usr/share/fzf/shell/key-bindings.fish   # fish
```

This installs `Ctrl-T`, `Ctrl-R`, and `Alt-C` bindings plus `**` tab completion.

---

## Basic Usage

```bash
# Filter a list of files (uses find by default)
fzf

# Pipe anything to fzf
ls | fzf
cat /etc/passwd | cut -d: -f1 | fzf
git branch | fzf

# Capture selection into a variable
selected=$(ls | fzf)
echo "You selected: $selected"

# Use selection directly
vim $(fzf)
cd $(find . -type d | fzf)

# Multi-select (Tab to toggle)
vim $(fzf -m)
```

---

## Sections

| Page | Contents |
|------|----------|
| [Search Syntax](search.md) | Fuzzy, exact, prefix, suffix, negation, AND/OR |
| [Key Options](options.md) | `--height`, `--layout`, `--multi`, `--nth`, `--header`, and more |
| [Preview Window](preview.md) | Real-time preview of each selection |
| [Key Bindings](keybindings.md) | Default keys and custom `--bind` actions |
| [Shell Integration](shell.md) | Ctrl-T, Ctrl-R, Alt-C, `**` completion |
| [Environment & Config](env.md) | `FZF_DEFAULT_OPTS`, `FZF_DEFAULT_COMMAND`, and more |
| [Recipes](recipes.md) | Shell functions for git, docker, kubectl, and more |
| [Integrations](integrations.md) | vim/neovim, git, kubectl, package managers |
