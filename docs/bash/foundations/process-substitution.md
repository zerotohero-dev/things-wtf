# Process Substitution


```bash title="<() and >() — treat process output as a file"
# <(cmd) — cmd output appears as a temporary file (fd or /dev/fd/N)
# Perfect when a tool wants a file path but you have a stream

# diff two command outputs without temp files
diff <(sort file1) <(sort file2)

# Compare local vs remote
diff <(cat /etc/hosts) <(ssh host 'cat /etc/hosts')

# Read from process substitution in while loop (important!)
# This preserves the parent shell's variables — unlike piping to while
while IFS= read -r line; do
  count+=1             # this WORKS — not in a subshell
done < <(find . -type f)

# vs. the WRONG way (cmd | while — while runs in subshell, changes lost)
# find . -type f | while IFS= read -r line; do count+=1; done  # count=0 after!

# >(cmd) — write to process substitution
tee >(gzip > archive.gz) >(wc -l) < input.txt

# Capture stderr separately without temp file
exec 2> >(while IFS= read -r line; do
  echo "[ERR] $line" >> /tmp/errors.log
done)
```
