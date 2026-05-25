# sed — Branching & Labels

sed has a minimal loop construct via `:label`, `b` (unconditional branch), `t` (branch if substitution succeeded), and `T` (branch if substitution failed, GNU).

---

## Branch Commands

| Command | Behavior |
|---------|----------|
| `: label` | Define a label (jump target). Label name is alphanumeric. |
| `b [label]` | Unconditionally jump to label. If no label, jump to end of script (skip remaining commands for this cycle). |
| `t [label]` | Jump to label **only if** a `s///` command has succeeded since the last input line was read or since the last `t`. |
| `T [label]` | Jump to label **only if NO** `s///` has succeeded. GNU extension; inverse of `t`. |

---

## Loop Until No More Matches

The classic use of `t`: keep applying a substitution until it no longer matches.

```bash
# Remove all leading whitespace (loop until none left)
sed ':loop; s/^[[:space:]]//; t loop' file.txt

# Remove all trailing whitespace
sed ':loop; s/[[:space:]]$//; t loop' file.txt

# Collapse multiple spaces into one (loop is cleaner than just /g)
sed ':loop; s/  / /; t loop' file.txt
# (though s/  */ /g is more efficient for this)
```

---

## Loop Over Multi-line Content

```bash
# Join continuation lines (lines ending with \)
sed ':a; /\\$/ { N; s/\\\n//; ba }' file.txt

# Join lines ending with a comma
sed ':a; /,$/ { N; s/,\n/,/; ba }' file.txt

# Remove multi-line C block comments
sed -E ':a; s|/\*[^*]*\*/||g; ta; /\/\*/ { N; ba }' file.c
```

---

## Skip Lines with b

Use `b` (branch to end of script) to skip all remaining commands for matching lines.

```bash
# Skip comment lines — don't process lines starting with #
sed '/^#/b; s/foo/bar/g' config.txt

# Skip header line in CSV
sed '1b; s/,/\t/g' data.csv

# Skip empty lines, process the rest
sed '/^$/b; s/^/  /' file.txt
```

---

## GNU T: Act Only When s/// Failed

```bash
# Tag lines where substitution did NOT occur
sed 's/ERROR/FOUND/; T skip; s/$/ <<< ALERT/; :skip' log

# Remove lines where a substitution could not be made
sed 's/[0-9]/X/g; T delete; b; :delete; d' file.txt
```

---

## Word-wrap Long Lines (crude)

```bash
# Insert a newline after every 72nd character
sed ':a; s/.\{73,\}/&\n/; ta' file.txt
```

---

!!! tip "Resetting the t flag"
    The `t` flag is reset at the start of each new input line and also immediately after a successful `t` branch. This means you can have multiple `t` tests in one script and they don't interfere with each other across branches.

!!! warning "Infinite Loops"
    A `:label; ...; b label` without a guard condition will loop forever. Always ensure the loop has an exit condition — typically the `t`/`T` mechanism (which stops branching when the substitution no longer matches), or an address that limits which lines enter the loop.
