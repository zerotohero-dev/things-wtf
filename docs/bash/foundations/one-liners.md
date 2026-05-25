# One-liners


```bash title="high-value one-liners"
# Find and replace recursively in files
grep -rl "old_string" . | xargs sed -i 's/old_string/new_string/g'

# Find files modified in last N minutes
find . -mmin -30 -type f

# Find and delete files older than N days
find /tmp -mtime +7 -delete

# Top 10 largest files in current dir
du -sh * | sort -rh | head -10

# Count occurrences of a string in all files
grep -r "pattern" . | wc -l

# Watch a log file for errors
tail -f /var/log/app.log | grep --line-buffered -iE "error|fatal|panic"

# Get HTTP status code only
curl -o /dev/null -s -w "%{http_code}" https://example.com

# Port scan (no nmap)
for p in {80,443,8080,8443}; do nc -zv -w1 host "$p" 2>&1; done

# Create directory tree and file in one shot
mkdir -p a/b/c && touch a/b/c/file.txt

# JSON field extract without jq
python3 -c "import sys,json; d=json.load(sys.stdin); print(d['key'])"

# Show all env vars containing a string
env | grep -i "vault"

# Kill all processes matching name
pkill -f "pattern"
pgrep -fa "pattern"   # list first (don't kill blindly)

# Check what's listening on a port
ss -tlnp | grep ":8080"
lsof -i :8080

# Watch a command output every N seconds
watch -n2 'kubectl get pods'

# Generate a random password
openssl rand -base64 32
tr -dc 'A-Za-z0-9!@#$%^' < /dev/urandom | head -c 24

# Add a line to file only if not already present
grep -qxF "line content" file || echo "line content" >> file

# Diff two directories
diff -rq dir1 dir2

# Create archive and show progress
tar -czf - /data | pv > backup.tar.gz

# Extract just the Nth line
sed -n '5p' file.txt
awk 'NR==5' file.txt

# Unique lines preserving order (sort | uniq loses order)
awk '!seen[$0]++' file.txt

# Sum a column of numbers
awk '{sum+=$1} END{print sum}' file.txt

# Show open file handles of a process
ls -la /proc/$PID/fd

# Follow a process tree
pstree -p $PID
```
