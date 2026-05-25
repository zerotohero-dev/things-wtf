# awk — Data Processor

> awk splits every input line into fields, then evaluates a list of pattern/action pairs against it. It's a full programming language — variables, arrays, arithmetic, string functions, user-defined functions — built around the stream model.

The name comes from its creators: **A**ho, **W**einberger, **K**ernighan.

---

## How awk Works

```
┌──────────────────────────────────────────────────────────────┐
│  For each record (line) of input:                            │
│                                                              │
│  1. Split record into fields $1, $2, … $NF using FS         │
│  2. Evaluate every pattern { action } rule in order:         │
│     - If pattern matches (or no pattern), run action         │
│  3. Loop                                                     │
│                                                              │
│  Before any input: run BEGIN { }                             │
│  After all input:  run END   { }                             │
└──────────────────────────────────────────────────────────────┘
```

---

## Invocation

```bash
awk [OPTIONS] 'PROGRAM' [FILE...]
awk [OPTIONS] -f script.awk [FILE...]
```

| Option | Meaning |
|--------|---------|
| `-F sep` | Set field separator (string or regex) |
| `-v var=val` | Set a variable before execution begins |
| `-f file` | Read program from file |

---

## Program Structure

```awk
awk '
  BEGIN  { # runs once before any input }
  /regex/ { # runs for lines matching regex }
  condition { # runs when condition is true }
           { # no pattern = runs on every line }
  END    { # runs once after all input }
' file
```

Multiple `BEGIN` and `END` blocks are allowed and run in order.

---

## Variants

!!! info "Which awk?"
    **awk** (POSIX), **gawk** (GNU awk — most feature-rich, default on Linux), **mawk** (fast, minimal), **nawk** (classic "new awk"). This guide targets **gawk**. On macOS the default awk is "one true awk" — install gawk via Homebrew for full compatibility: `brew install gawk`.

---

## Sections

| Page | Contents |
|------|----------|
| [Fields & Records](fields.md) | `$0`, `$NF`, `NR`, `FNR`, field separators |
| [Built-in Variables](variables.md) | `FS`, `OFS`, `RS`, `ORS`, `ENVIRON`, `FPAT`, and more |
| [Patterns & Actions](patterns.md) | `BEGIN`/`END`, regexes, ranges, `BEGINFILE`/`ENDFILE` |
| [Control Flow](control.md) | `if`, `while`, `for`, `next`, `exit`, `break` |
| [String Functions](strings.md) | `sub`, `gsub`, `gensub`, `split`, `match`, `sprintf`, and more |
| [Math Functions](math.md) | Arithmetic, `rand`, aggregation patterns |
| [Arrays](arrays.md) | Associative arrays, multi-dim, `delete`, `in` |
| [I/O & Printf](io.md) | `print`, `printf`, redirects, pipes, `getline` |
| [User Functions](functions.md) | Defining functions, local variables idiom, recursion |
| [Recipes](recipes.md) | Real-world one-liners and programs |
