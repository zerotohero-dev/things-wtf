# 3am Triage

> **pager survival kit**

You just got woken up. Half asleep. Something is down. These are the commands you need, in the order you need them.


```bash title="system state — first 60 seconds"
# What is the system doing?
uptime                    # load average
top -bn1 | head -20     # snapshot (non-interactive)
htop                     # interactive (better)

# What's eating CPU?
ps aux | sort -k3rn | head -10

# What's eating memory?
ps aux | sort -k4rn | head -10
free -h

# Disk
df -h                    # filesystem usage
du -sh /* 2>/dev/null    # what's big in /
lsof | grep " deleted"  # files deleted but still open (disk leak)

# Network
ss -s                    # socket summary
ss -tlnp                 # listening ports + processes
ss -tnp state established | wc -l  # count open connections
netstat -an | grep "TIME_WAIT" | wc -l  # TIME_WAIT connections

# Recent system messages
dmesg -T | tail -50     # kernel messages with timestamps
journalctl -xe --no-pager | tail -100
journalctl -u myservice -n 200 --no-pager  # specific service
journalctl --since "10 minutes ago" --no-pager
last -x | head -20      # recent logins / shutdowns
```


```bash title="kubernetes triage"
# Quick overview
kubectl get pods -A | grep -v Running | grep -v Completed
kubectl get events -A --sort-by=.lastTimestamp | tail -30
kubectl top nodes
kubectl top pods -A

# Investigate a specific pod
kubectl describe pod "$POD" -n "$NS"
kubectl logs "$POD" -n "$NS" --previous     # last crashed container
kubectl logs "$POD" -n "$NS" --since=5m
kubectl logs -l app=myapp -n "$NS" --all-containers --since=5m

# Exec into a pod
kubectl exec -it "$POD" -n "$NS" -- /bin/sh
kubectl exec -it "$POD" -n "$NS" -c "$CONTAINER" -- bash

# Copy files out
kubectl cp "$NS/$POD:/app/logs" ./logs

# Restart a deployment
kubectl rollout restart deploy/"$DEPLOY" -n "$NS"
kubectl rollout status deploy/"$DEPLOY" -n "$NS"
kubectl rollout undo deploy/"$DEPLOY" -n "$NS"  # rollback

# Scale down/up
kubectl scale deploy/"$DEPLOY" --replicas=0 -n "$NS"
kubectl scale deploy/"$DEPLOY" --replicas=3 -n "$NS"

# Force-delete stuck pod
kubectl delete pod "$POD" -n "$NS" --force --grace-period=0

# Patch annotation (e.g. flux reconcile)
kubectl annotate helmrelease "$HR" -n "$NS" \
  reconcile.fluxcd.io/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```


```bash title="disk is full — diagnosis & cleanup"
# Find biggest files
find / -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -20

# Find biggest directories
du -xh / 2>/dev/null | sort -rh | head -20

# Files open but deleted (not freed until process closes)
lsof | awk '/deleted/{print $2, $7, $9}' | sort -k2rn

# Truncate a log (don't delete if process has it open)
> /var/log/bigfile.log     # safe truncate

# Docker cleanup
docker system prune -af --volumes

# Journald cleanup
journalctl --vacuum-size=200M
journalctl --vacuum-time=7d

# Find and remove core dumps
find / -name 'core.*' -o -name 'core' 2>/dev/null | xargs -r ls -lh
```


```bash title="process not responding / memory leak"
# Find the process
pgrep -fa "appname"
PID=$(pgrep -o "appname")   # oldest matching process

# Check memory maps
cat /proc/$PID/status
cat /proc/$PID/smaps | grep -i pss | awk '{sum+=$2} END{print sum"kB"}'

# Get stack trace without debugger (Linux)
cat /proc/$PID/wchan     # kernel wait channel (what it's blocked on)
gdb -p $PID -ex "thread apply all bt" -ex detach -ex quit 2>/dev/null

# Send signals
kill -USR1 $PID          # custom signal (often triggers goroutine dump)
kill -ABRT $PID          # core dump
kill -TERM $PID          # graceful shutdown (try first)
kill -9 $PID             # last resort — cannot be caught/ignored
kill -9 -$PGID           # kill entire process group

# Check file descriptors (fd exhaustion)
ls /proc/$PID/fd | wc -l
cat /proc/sys/fs/file-nr   # system-wide: open, free, max
```


```bash title="network is broken"
# Can I reach anything?
ping -c3 8.8.8.8              # basic IP reachability
ping -c3 google.com            # DNS + reachability

# DNS debug
dig +short google.com          # basic lookup
dig @8.8.8.8 google.com        # use specific resolver
nslookup google.com            # alternative
cat /etc/resolv.conf           # check configured resolvers

# Trace the path
traceroute -n google.com
mtr -n google.com              # better, real-time

# TCP connectivity test
nc -zv host 443               # test port open
nc -zv -w3 host 443           # with 3s timeout
curl -v --connect-timeout 5 https://host  # full TLS debug

# TLS certificate check
echo | openssl s_client -connect host:443 2>/dev/null | openssl x509 -noout -dates

# Capture traffic (quick diagnosis)
tcpdump -i eth0 -nn host google.com -c 20
tcpdump -i any port 8080 -A -c 10    # capture and print payload

# Iptables check
iptables -L -n -v --line-numbers
iptables -t nat -L -n -v           # NAT rules
```


```bash title="miscellaneous survival commands"
# Run last command as root
sudo !!

# Repeat last argument
ls /very/long/path
cd $_                  # $_ = last arg of previous command

# History search
history | grep "kubectl"
!kubectl               # re-run last kubectl command

# Send stdin to clipboard (macOS/X11)
cat file | pbcopy       # macOS
cat file | xclip -sel c  # X11 Linux

# Fix "too many arguments" with xargs
cat hugelist.txt | xargs -P4 -n1 process_item

# Quick http server in current dir
python3 -m http.server 8080

# Base64 encode/decode
echo -n "secret" | base64
echo "c2VjcmV0" | base64 -d

# Decode k8s secret
kubectl get secret "$SECRET" -o json |
  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'

# Recursively list all function definitions in a script
grep -n "^[[:space:]]*function\|^[[:space:]]*[a-z_]*[[:space:]]*()" script.sh

# Time a command
time kubectl apply -f deploy.yaml

# Get script's absolute directory (ALWAYS use this)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running interactively
[[ -t 0 ]] && echo "interactive" || echo "piped/non-interactive"

# Check if running as root
[[ $EUID -eq 0 ]] || die "Run as root"
```
