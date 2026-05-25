# sed — Stream Editor

> **sed** reads input line by line into the *pattern space*, applies commands, prints the pattern space, and loops. The mental model: it's a loop + a buffer + a script.

---

## How sed Works

```
┌──────────────────────────────────────────────────────────┐
│  For each line of input:                                 │
│                                                          │
│  1. Read line into PATTERN SPACE                         │
│  2. Execute all commands in the script                   │
│  3. (Unless -n) print pattern space                      │
│  4. Clear pattern space, go to next line                 │
│                                                          │
│  HOLD SPACE persists across cycles (starts empty)        │
└──────────────────────────────────────────────────────────┘
```

---

## Invocation

```bash
sed [OPTIONS] 'SCRIPT' [FILE...]
sed [OPTIONS] -e 'CMD1' -e 'CMD2' [FILE...]
sed [OPTIONS] -f script.sed [FILE...]
```

### Options

| Option | Meaning |
|--------|---------|
| `-n` | Suppress automatic printing; only print when explicitly told to (`p` command) |
| `-e 'script'` | Add a script expression (multiple `-e` allowed) |
| `-f file` | Read script from a file |
| `-i[SUFFIX]` | Edit file in-place; optional suffix creates a backup (`-i.bak`) |
| `-E` / `-r` | Use extended regular expressions (ERE) — enables `+`, `?`, `|`, `()`, `{}` without backslash |
| `-s` | Treat each file separately (line numbers reset per file) |
| `--sandbox` | GNU sed: disallow `r`/`w`/`e` commands (safe mode) |

### Command structure

A sed command has the form:

```
[address[,address]]command[flags]
```

!!! warning "macOS vs GNU sed"
    macOS ships BSD sed. For full GNU sed behavior — especially `-i` without a suffix — install `gnu-sed` via Homebrew (`brew install gnu-sed`) and invoke as `gsed`, or prepend it to your PATH.

---

## Sections

| Page | Contents |
|------|----------|
| [Addressing](addresses.md) | Line numbers, regexes, ranges, negation |
| [Substitution](substitute.md) | The `s` command — flags, backreferences, case conversion |
| [Core Commands](commands.md) | `d p q a i c y n N h H g G x` and more |
| [Pattern & Hold Space](spaces.md) | The two buffers and how to use them |
| [Multi-line](multiline.md) | `N`, `P`, `D` and the sliding window idiom |
| [Branching](branching.md) | `:label`, `b`, `t`, `T` — loops inside sed |
| [In-place Editing](inplace.md) | `-i`, backups, recursive replacement |
| [Recipes](recipes.md) | Real-world one-liners and scripts |
