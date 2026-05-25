# Channel Patterns

Recurring patterns for orchestrating goroutines with channels. These are the building blocks of concurrent Go programs.

---

## Pipeline

Chain goroutines using channels: the output of one stage feeds the input of the next. Each stage runs concurrently.

```go
// Stage 1: emit values
func generate(nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        for _, n := range nums { out <- n }
        close(out)
    }()
    return out
}

// Stage 2: transform each value
func square(in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        for n := range in { out <- n * n }
        close(out)
    }()
    return out
}

// Chain stages: generate → square → square → print
for n := range square(square(generate(2, 3, 4))) {
    fmt.Println(n) // 16, 81, 256
}
```

**Key properties of a well-designed pipeline:**

- Each stage receives from an upstream channel and sends to a downstream channel.
- Each stage closes its output channel when done, signalling downstream.
- Stages should respect a cancellation signal (via context or done channel) to avoid goroutine leaks when a downstream stage exits early.

---

## Fan-Out

Distribute work from **one channel** across **multiple workers**. All workers read from the same input — whoever is free picks up the next item.

```go
func fanOut(ctx context.Context, in <-chan Job, numWorkers int) []<-chan Result {
    outputs := make([]<-chan Result, numWorkers)
    for i := range numWorkers {
        outputs[i] = startWorker(ctx, in) // each reads from shared 'in'
    }
    return outputs
}

func startWorker(ctx context.Context, in <-chan Job) <-chan Result {
    out := make(chan Result)
    go func() {
        defer close(out)
        for {
            select {
            case job, ok := <-in:
                if !ok { return }
                out <- process(job)
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}
```

---

## Fan-In (Merge)

Collect results from **multiple channels** into one. Use when fan-out workers each have their own output channel.

```go
func fanIn(ctx context.Context, inputs ...<-chan Result) <-chan Result {
    out := make(chan Result)
    var wg sync.WaitGroup

    forward := func(c <-chan Result) {
        defer wg.Done()
        for {
            select {
            case v, ok := <-c:
                if !ok { return }
                out <- v
            case <-ctx.Done():
                return
            }
        }
    }

    wg.Add(len(inputs))
    for _, c := range inputs { go forward(c) }

    // Close output once all forwarders are done
    go func() { wg.Wait(); close(out) }()
    return out
}
```

---

## Worker Pool

A **fixed number** of goroutines consuming from a shared job queue. Prevents goroutine explosion when the number of jobs is large or unbounded.

```go
func workerPool(
    ctx        context.Context,
    numWorkers int,
    jobs       <-chan Job,
) <-chan Result {
    results := make(chan Result, numWorkers)
    var wg sync.WaitGroup

    for range numWorkers {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for {
                select {
                case job, ok := <-jobs:
                    if !ok { return }
                    results <- process(job)
                case <-ctx.Done():
                    return
                }
            }
        }()
    }

    go func() { wg.Wait(); close(results) }()
    return results
}

// Usage
jobs := make(chan Job, 100)
go func() {
    defer close(jobs)
    for _, j := range allJobs { jobs <- j }
}()

for result := range workerPool(ctx, 8, jobs) {
    handle(result)
}
```

---

## Semaphore via Buffered Channel

A buffered channel with capacity N acts as a semaphore: at most N goroutines proceed at once. Simple and requires no external package.

```go
sem := make(chan struct{}, 10) // max 10 concurrent

var wg sync.WaitGroup
for _, url := range urls {
    wg.Add(1)
    go func(u string) {
        defer wg.Done()
        sem <- struct{}{}        // acquire slot
        defer func() { <-sem }() // release slot
        fetch(u)
    }(url)
}
wg.Wait()
```

!!! tip "golang.org/x/sync/semaphore"
    For weighted semaphores (where tasks have different "costs"), use
    `golang.org/x/sync/semaphore` which supports `Acquire(ctx, weight)`.

---

## Pipeline with Early Exit

When a downstream stage exits early (e.g., only needs the first N results), upstream goroutines must not be left blocked. Pass a done channel or context so they can exit cleanly.

```go
func take(ctx context.Context, in <-chan int, n int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for i := 0; i < n; i++ {
            select {
            case v, ok := <-in:
                if !ok { return }
                out <- v
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

// Usage: only take first 5 results from a pipeline
ctx, cancel := context.WithCancel(context.Background())
defer cancel() // signals upstream stages to stop

for v := range take(ctx, square(generate(1,2,3,4,5,6,7,8,9,10)), 5) {
    fmt.Println(v)
}
```

---

## sync.Once — Single Initialization

```go
var (
    dbOnce   sync.Once
    dbConn   *sql.DB
)

func GetDB() *sql.DB {
    dbOnce.Do(func() {
        var err error
        dbConn, err = sql.Open("pgx", os.Getenv("DATABASE_URL"))
        if err != nil {
            panic(err) // only acceptable in init paths
        }
    })
    return dbConn
}

// Do guarantees the function runs exactly once,
// even if called concurrently from 1000 goroutines.
```

---

## Heartbeat Pattern

A goroutine that periodically signals it's still alive — useful for long-running workers and health checks.

```go
func worker(ctx context.Context, jobs <-chan Job) (<-chan Result, <-chan struct{}) {
    results   := make(chan Result)
    heartbeat := make(chan struct{}, 1) // buffered: don't block worker

    go func() {
        defer close(results)
        ticker := time.NewTicker(1 * time.Second)
        defer ticker.Stop()

        for {
            select {
            case <-ticker.C:
                select {
                case heartbeat <- struct{}{}: // signal alive
                default:                      // drop if nobody listening
                }
            case job, ok := <-jobs:
                if !ok { return }
                results <- process(job)
            case <-ctx.Done():
                return
            }
        }
    }()

    return results, heartbeat
}
```

---

## Pattern Summary

| Pattern | Problem it solves |
|---------|------------------|
| Pipeline | Stage-by-stage data transformation with concurrency |
| Fan-out | Parallelize work across multiple workers |
| Fan-in | Collect results from multiple workers into one stream |
| Worker pool | Cap concurrency when work is unbounded |
| Semaphore | Limit concurrent access to a resource |
| Done channel | Broadcast cancellation to many goroutines |
| sync.Once | Run initialization exactly once, safely |
| Heartbeat | Monitor long-running goroutines |
