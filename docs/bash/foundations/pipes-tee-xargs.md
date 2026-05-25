# Pipes, tee, xargs


```bash title="pipes & pipeline patterns"
# Basic pipe — connect stdout of left to stdin of right
cat file.txt | grep "error" | sort | uniq -c | sort -rn

# Check exit code of specific pipe stage
cmd1 | cmd2 | cmd3
echo "${PIPESTATUS[@]}"     # e.g. "0 1 0" (cmd2 failed)
[[ "${PIPESTATUS[1]}" -eq 0 ]] || die "cmd2 failed"

# tee — split pipeline to file AND continue
curl -sL "$url" | tee raw.json | jq '.'

# Named pipe (FIFO) — bidirectional IPC
mkfifo /tmp/mypipe
producer > /tmp/mypipe &
consumer < /tmp/mypipe
rm /tmp/mypipe

# xargs — pipe to arguments (not stdin)
find . -name '*.log' | xargs rm               # risky if filenames have spaces
find . -name '*.log' -print0 | xargs -0 rm   # NUL-safe (always use this)
find . -name '*.log' -print0 | xargs -0 -I{} mv {} /archive/  # placeholder

# xargs parallel execution
cat hosts.txt | xargs -P4 -I{} ssh {} 'uptime'  # 4 parallel ssh

# GNU parallel (better than xargs for complex jobs)
parallel -j4 process_file ::: *.txt
```
