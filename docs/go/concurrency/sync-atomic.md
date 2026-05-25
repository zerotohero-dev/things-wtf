# sync & atomic

When channels are the wrong tool — protecting a shared data structure, coordinating one-time init, or squeezing out lock-free performance — reach for the `sync` and `sync/atomic` packages.

## sync.Mutex / sync.RWMutex

```go
// Mutex: exclusive access (one reader OR one writer at a time)
var mu sync.Mutex

mu.Lock()
defer mu.Unlock()
// critical section

// RWMutex: multiple readers OR one writer
var rw sync.RWMutex

// Read lock — multiple goroutines can hold this simultaneously
rw.RLock()
defer rw.RUnlock()

// Write lock — exclusive
rw.Lock()
defer rw.Unlock()
```

### Embedding Mutex in a Struct

```go
type SafeMap struct {
    mu sync.RWMutex
    m  map[string]int
}

func (s *SafeMap) Get(key string) (int, bool) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    v, ok := s.m[key]
    return v, ok
}

func (s *SafeMap) Set(key string, val int) {
    s.mu.Lock()
    defer s.mu.Unlock()
    if s.m == nil {
        s.m = make(map[string]int)
    }
    s.m[key] = val
}
```

!!! danger "Mutexes must never be copied"
    Once a `sync.Mutex` has been used, copying the struct that contains it creates two
    independent locks over the same data. Always pass and store structs with mutexes by **pointer**.
    `go vet` will catch copies.

## sync.Map

A concurrent map optimized for **high-read, stable-key** workloads. For most use cases, a plain `map` + `sync.RWMutex` is simpler and equally fast.

```go
var sm sync.Map

// Store
sm.Store("key", 42)

// Load
v, ok := sm.Load("key")
if ok {
    fmt.Println(v.(int))
}

// LoadOrStore — atomic "get or set"
actual, loaded := sm.LoadOrStore("key", 99)
// loaded=true if key existed, actual = existing value

// Delete
sm.Delete("key")

// Range — iterate (order not guaranteed)
sm.Range(func(k, v any) bool {
    fmt.Println(k, v)
    return true // return false to stop
})
```

!!! tip "sync.Map vs map + RWMutex"
    Prefer `sync.Map` when: the key set is written once and read many times, or when many goroutines read different keys (low contention per-key). Prefer `map + RWMutex` when: you update frequently, need `len()`, or want simpler code.

## sync.WaitGroup

See [Goroutines](goroutines.md) for full coverage. Quick reference:

```go
var wg sync.WaitGroup

wg.Add(n)       // add n before launching goroutines
wg.Done()       // call from each goroutine when finished
wg.Wait()       // block until count reaches zero
```

## sync.Once

Guarantees a function runs **exactly once**, even under concurrent calls.

```go
var once sync.Once

func getInstance() *Singleton {
    once.Do(func() {
        instance = &Singleton{} // runs only on the first call
    })
    return instance
}
```

## sync.Cond

A condition variable — lets goroutines wait for a condition to be true without spinning. Rarely needed; channels or semaphores cover most cases. Useful for **broadcast wakeup** (like a start gate).

```go
var mu sync.Mutex
cond := sync.NewCond(&mu)
ready := false

// Goroutines waiting for the signal
for i := 0; i < 5; i++ {
    go func(id int) {
        mu.Lock()
        for !ready {
            cond.Wait() // atomically: unlock mu, sleep; re-lock on wake
        }
        mu.Unlock()
        fmt.Printf("goroutine %d starting\n", id)
    }(i)
}

// Broadcaster
time.Sleep(1 * time.Second)
mu.Lock()
ready = true
cond.Broadcast() // wake ALL waiting goroutines (Signal wakes one)
mu.Unlock()
```

## sync/atomic

Lock-free operations on primitive types. Lower overhead than a mutex for simple counters and flags.

```go
import "sync/atomic"

var counter int64

// Read-modify-write (atomic)
atomic.AddInt64(&counter, 1)
atomic.AddInt64(&counter, -1)

// Read
n := atomic.LoadInt64(&counter)

// Write
atomic.StoreInt64(&counter, 0)

// Compare-and-swap — the foundation of lock-free algorithms
old, new := int64(5), int64(10)
swapped := atomic.CompareAndSwapInt64(&counter, old, new)
// swapped=true if counter was 5 and is now 10

// atomic.Value — store/load any value atomically (useful for hot config)
var cfg atomic.Value

cfg.Store(MyConfig{Timeout: 30}) // store must always be the same concrete type
current := cfg.Load().(MyConfig) // type assertion needed
```

### Using atomic.Value for Hot Config Reloading

```go
type Config struct {
    Timeout time.Duration
    Debug   bool
}

var liveConfig atomic.Value

func init() {
    liveConfig.Store(Config{Timeout: 30 * time.Second})
}

// Reload from disk without locking readers
func reloadConfig() {
    c := parseConfigFile()
    liveConfig.Store(c) // all subsequent loads see the new value
}

func handleRequest() {
    cfg := liveConfig.Load().(Config) // always a consistent snapshot
    // use cfg.Timeout ...
}
```

## Race Detector

!!! tip "Always run with -race in CI"
    The race detector instruments memory accesses and reports true data races at runtime.
    It adds ~5–10× overhead but is invaluable during development and testing.

```sh
go test -race ./...
go run -race main.go
go build -race -o myapp .
```

## Choosing the Right Tool

| Situation | Tool |
|-----------|------|
| Transfer ownership of data between goroutines | Channel |
| Broadcast a stop signal | `close(done)` or `context.Cancel` |
| Protect a struct with short critical sections | `sync.Mutex` |
| Many readers, infrequent writes | `sync.RWMutex` |
| Run exactly once | `sync.Once` |
| High-performance counter or flag | `sync/atomic` |
| Hot-reloadable config (read-heavy) | `atomic.Value` |
| Concurrent map, stable keys | `sync.Map` |
| Broadcast wakeup (start gate, barrier) | `sync.Cond` |
