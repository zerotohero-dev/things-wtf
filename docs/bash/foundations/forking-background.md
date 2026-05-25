# Forking & Background Jobs


```bash title="background processes & job control"
# & — fork to background, shell continues immediately
sleep 10 &
sleep_pid=$!        # capture PID of last backgrounded process

# wait — block until job(s) finish
wait                 # wait for ALL background jobs
wait $sleep_pid      # wait for specific PID
wait $p1 $p2 $p3    # wait for multiple

# Parallel execution with wait
pids=()
for host in "${hosts[@]}"; do
  ssh "$host" 'uptime' &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid" || echo "pid $pid failed"
done

# Parallel with concurrency limit
run_with_limit() {
  local max="$1"; shift
  local pids=()
  for item in "$@"; do
    while [[ "${#pids[@]}" -ge "$max" ]]; do
      wait -n || true    # bash 4.3+ wait for any one job
      # reap finished pids from array
      pids=($(for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && echo "$p"; done))
    done
    process "$item" &
    pids+=($!)
  done
  wait
}

# Job control commands
jobs                 # list background jobs
jobs -l             # with PIDs
fg %1               # bring job 1 to foreground
bg %1               # resume job 1 in background
kill %1             # kill job 1 (job spec)

# disown — detach from shell (won't be killed on exit)
long_process &
disown $!

# nohup — immune to SIGHUP, redirects to nohup.out
nohup long_process &> /tmp/output.log &

# Wait for process from outside (polling)
while kill -0 "$pid" 2>/dev/null; do
  sleep 0.5
done
```
