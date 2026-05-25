# Channels

Channels are typed conduits for goroutine communication and synchronization. They carry values of a specific type and can be unbuffered (synchronous) or buffered (asynchronous).

## Creating Channels

```go
// Unbuffered: sender blocks until a receiver is ready (rendezvous)
ch := make(chan int)

// Buffered: sender blocks only when the buffer is full
bch := make(chan int, 10)

// Directional types — communicate intent at compile time
func producer(out chan<- int) { out <- 1 } // send-only
func consumer(in <-chan int)  { <-in }     // receive-only

// Bidirectional channels convert to directional implicitly
ch := make(chan int)
go producer(ch) // chan int → chan<- int ✓
go consumer(ch) // chan int → <-chan int ✓
```

## Sending, Receiving, Closing

```go
ch <- 42          // send (blocks if unbuffered and no receiver)
v  := <-ch        // receive (blocks if no value ready)
v, ok := <-ch     // ok = false if channel is closed and drained

close(ch)         // signal "no more values"

// Range over a channel — exits cleanly when closed
for v := range ch {
    fmt.Println(v)
}
```

## Channel Axioms

Knowing these cold prevents panics and deadlocks:

| Operation | nil channel | closed channel | open channel |
|-----------|-------------|----------------|--------------|
| Send | blocks forever | **panic** | blocks or succeeds |
| Receive | blocks forever | returns zero + `ok=false` | blocks or succeeds |
| Close | **panic** | **panic** | signals done |

!!! danger "Only the sender should close a channel"
    Closing a channel is a signal from producer to consumer: "no more values coming."
    Closing from the consumer side, or closing twice, **panics**.
    If multiple goroutines produce into one channel, coordinate closing with a WaitGroup and a single closer.

```go
// ✓ Single closer pattern
func merge(inputs ...<-chan int) <-chan int {
    out := make(chan int)
    var wg sync.WaitGroup
    wg.Add(len(inputs))

    for _, ch := range inputs {
        go func(c <-chan int) {
            defer wg.Done()
            for v := range c { out <- v }
        }(ch)
    }

    // One goroutine closes — only after all senders are done
    go func() { wg.Wait(); close(out) }()
    return out
}
```

## Select — Multiplexing

`select` waits on multiple channel operations simultaneously. If multiple cases are ready, it picks one **at random**.

```go
select {
case msg := <-ch1:
    fmt.Println("from ch1:", msg)
case msg := <-ch2:
    fmt.Println("from ch2:", msg)
case <-time.After(1 * time.Second):
    fmt.Println("timed out")
case <-ctx.Done():
    return ctx.Err()
default:
    // Non-blocking: runs immediately if no other case is ready
    fmt.Println("nothing ready")
}
```

### Non-Blocking Send/Receive

```go
// Non-blocking receive
select {
case v := <-ch:
    use(v)
default:
    // ch was empty
}

// Non-blocking send
select {
case ch <- value:
    // sent
default:
    // ch was full or no receiver
}

// Send with timeout
select {
case result <- value:
    // delivered
case <-time.After(100 * time.Millisecond):
    fmt.Println("send timed out — dropping")
}
```

## Unbuffered vs Buffered

| | Unbuffered | Buffered |
|-|------------|---------|
| Sync | Strong — sender and receiver meet | Weak — sender proceeds if buffer has space |
| Backpressure | Natural — sender slows to match receiver | Delayed — pressure felt when buffer fills |
| Use for | Guaranteeing handoff, signaling | Decoupling bursty producers from consumers |
| Goroutine leak risk | High if receiver never arrives | Lower, but buffer size must be reasoned about |

!!! tip "Choosing buffer size"
    Size 0 (unbuffered) for synchronization and signaling. Size 1 for "at most one pending item" (e.g., a timeout signal). Size N where N = max burst you expect to absorb. Avoid `make(chan T, 1000)` as a knee-jerk fix for goroutine leaks — understand the flow first.

## Done Channels — Cancellation

Closing a channel **broadcasts** to all goroutines waiting on it simultaneously.

```go
done := make(chan struct{})

for i := 0; i < 3; i++ {
    go func(id int) {
        select {
        case <-jobs:
            // do work
        case <-done:
            fmt.Printf("worker %d stopping\n", id)
            return
        }
    }(i)
}

close(done) // all 3 workers receive the signal at once
```

Prefer `context.Context` over raw done channels in production code — it's standard, composable, and carries deadlines:

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

select {
case result := <-computeCh:
    use(result)
case <-ctx.Done():
    return ctx.Err() // context.DeadlineExceeded or Canceled
}
```
