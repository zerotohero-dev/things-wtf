# Goroutines

A goroutine is a lightweight, multiplexed thread managed by the Go runtime. Starting one is as cheap as a function call (~2 KB initial stack vs ~8 MB for an OS thread). The runtime multiplexes thousands of goroutines onto a handful of OS threads via the **M:N scheduler**.

## Starting Goroutines

```go
go someFunction(args)  // launch in background

// Anonymous goroutine — capture args explicitly
go func(msg string) {
    fmt.Println(msg)
}("hello") // arg passed immediately, avoiding closure capture issue
```

## Waiting with WaitGroup

```go
var wg sync.WaitGroup

for i := 0; i < 5; i++ {
    wg.Add(1)           // increment before launching
    go func(id int) {
        defer wg.Done() // decrement when goroutine exits
        fmt.Printf("worker %d done\n", id)
    }(i)
}

wg.Wait() // blocks until all Done() calls are made
```

!!! tip "Add before go"
    Always call `wg.Add(1)` **before** launching the goroutine — not inside it.
    If the goroutine is scheduled and completes before `Add` is called, `Wait` may return early.

## errgroup — WaitGroup with Error Propagation

```go
import "golang.org/x/sync/errgroup"

g, ctx := errgroup.WithContext(context.Background())

for _, url := range urls {
    url := url // capture per iteration (or use Go 1.22+)
    g.Go(func() error {
        return fetch(ctx, url)
    })
}

if err := g.Wait(); err != nil {
    log.Fatal(err) // first non-nil error from any goroutine
}
// ctx is automatically cancelled when any goroutine returns an error
```

## The Stopping Condition Rule

!!! danger "If you start it, you must be able to stop it"
    Every goroutine needs a clear exit path. Without one, it leaks — holding memory and
    preventing the garbage collector from reclaiming closured variables.

```go
// ✓ Always provide a stopping mechanism
func startWorker(ctx context.Context, jobs <-chan Job) {
    go func() {
        for {
            select {
            case job, ok := <-jobs:
                if !ok { return } // channel closed
                process(job)
            case <-ctx.Done():
                return // context cancelled
            }
        }
    }()
}
```

## Goroutine Lifecycle Patterns

| Pattern | When to use |
|---------|------------|
| `sync.WaitGroup` | Wait for a fixed set of goroutines to finish |
| `errgroup` | Same, but you need to collect errors |
| context cancellation | Propagate stop signals through a goroutine tree |
| done channel | Simple "stop now" signal to one or many goroutines |
| channel close | Broadcast to all receivers simultaneously |

## GOMAXPROCS

```go
// Default: number of logical CPUs
// Controls how many goroutines run truly in parallel
runtime.GOMAXPROCS(4)

// Check current value
n := runtime.GOMAXPROCS(0) // 0 = query, don't change
```
