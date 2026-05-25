# sed — In-place Editing

The `-i` flag edits files in-place, redirecting output back to the same file. This is one of the most commonly used sed features in scripts and CI pipelines.

---

## Basic Usage

```bash
# GNU sed: -i with no suffix (no backup)
sed -i 's/v1\.0/v1.1/g' version.go

# With backup — works on both GNU and BSD sed
sed -i.bak 's/foo/bar/g' config.yaml
# Creates config.yaml.bak before modifying config.yaml

# BSD/macOS sed: -i REQUIRES an argument (even empty string)
sed -i '' 's/foo/bar/g' file.txt   # macOS
```

---

## GNU vs BSD Compatibility

| Behavior | GNU sed | BSD sed (macOS) |
|----------|---------|-----------------|
| `-i` with no backup | `sed -i 's/a/b/'` | **Not supported** — requires suffix |
| `-i` with backup | `sed -i.bak 's/a/b/'` | `sed -i .bak 's/a/b/'` (space before suffix) |
| Portable syntax | `sed -i.bak` | `sed -i.bak` |

The most portable form is always `sed -i.bak` — it works on both.

On macOS with GNU sed installed via Homebrew:

```bash
# Use gsed to get GNU behavior on macOS
gsed -i 's/foo/bar/g' file.txt

# Or add to PATH: export PATH="$(brew --prefix gnu-sed)/libexec/gnubin:$PATH"
```

---

## Editing Multiple Files

```bash
# Edit multiple files matching a glob
sed -i 's/OLD_API/NEW_API/g' *.go

# Edit all YAML files recursively (GNU find + sed)
find . -name '*.yaml' -exec sed -i 's/image: old/image: new/g' {} +

# With fd (faster)
fd -e yaml -x sed -i 's/image: old/image: new/g' {}
```

---

## Scoped In-place Edits

```bash
# Only replace in specific line range
sed -i '1,5s/Copyright 2023/Copyright 2024/' *.go

# Only edit lines NOT matching a pattern
sed -i '/^#/!s/old/new/g' config.txt

# Only edit the last line
sed -i '$s/old/new/' file.txt
```

---

## Common Recipes

```bash
# Update a version number in a Go file
sed -i 's/version = "[^"]*"/version = "2.0.0"/' cmd/root.go

# Strip trailing whitespace from all Go files
find . -name '*.go' -exec sed -i 's/[[:space:]]*$//' {} +

# Comment out a specific config line
sed -i '/^LoadModule ssl_module/s/^/# /' httpd.conf

# Uncomment a config line
sed -i 's/^# \(LoadModule ssl_module\)/\1/' httpd.conf

# Prepend a shebang line to a script
sed -i '1s/^/#!/usr/bin/env bash\n/' script.sh

# Add a blank line after a specific line
sed -i '/^---$/a\\' doc.md
```

---

!!! warning "No Undo"
    There is no undo for `-i` without a backup suffix. In any automated script (CI, Makefile), always use `-i.bak` or test the command thoroughly without `-i` first. Consider committing the file to git before running bulk replacements.

!!! tip "Test First"
    Always run the command **without** `-i` first to inspect output:
    ```bash
    # Test
    sed 's/old/new/g' important.yaml

    # Then apply
    sed -i 's/old/new/g' important.yaml
    ```
