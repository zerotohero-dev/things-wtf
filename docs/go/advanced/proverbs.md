# Go Proverbs

Go Proverbs are pithy design principles from Rob Pike's [2015 talk](https://go-proverbs.github.io/).
They distill idiomatic Go into memorable maxims — each one encodes a hard-won lesson.

---

## Don't communicate by sharing memory; share memory by communicating.

!!! quote ""
    Instead of protecting a shared variable with a mutex, **pass data through channels**.
    The channel *is* the synchronization. This leads to clearer ownership — one goroutine owns data at a time, and ownership transfers when the value is sent.

=== "✗ Sharing memory"
    ```go
    // Coordination is implicit — easy to miss a lock
    var balance int
    var mu sync.Mutex

    func deposit(amount int) {
        mu.Lock()
        balance += amount
        mu.Unlock()
    }
    ```

=== "✓ Communicating via channel"
    ```go
    // Only the bank goroutine ever touches balance — no lock needed
    type txn struct {
        amount int
        reply  chan int
    }

    func bank(ops chan txn) {
        balance := 0
        for op := range ops {
            balance += op.amount
            op.reply <- balance
        }
    }
    ```

---

## Concurrency is not parallelism.

!!! quote ""
    **Concurrency** is about structuring a program as independent tasks that *can* overlap.
    **Parallelism** is about actually running them simultaneously. A concurrent program on one core is still concurrent.
    Go's goroutines give you concurrency; `GOMAXPROCS` controls parallelism.

```go
// Concurrent: multiple goroutines, may or may not run in parallel
go fetch(url1)
go fetch(url2)
// How many actually run in parallel depends on GOMAXPROCS (default: num CPUs)

// You can run all goroutines on one OS thread:
runtime.GOMAXPROCS(1)
```

---

## Channels orchestrate; mutexes serialize.

!!! quote ""
    Channels are for **coordinating goroutines** — pipelines, signaling done, distributing work.
    Mutexes are for **protecting a shared resource** when goroutines just need exclusive access.
    Use the simpler tool: if it's "protect this counter," reach for a mutex.

```go
// Mutex: protecting a shared cache
var mu sync.Mutex
var cache = map[string]string{}
func get(k string) string {
    mu.Lock(); defer mu.Unlock(); return cache[k]
}

// Channel: orchestrating a worker pool
jobs := make(chan Job, 100)
for i := 0; i < numWorkers; i++ {
    go worker(jobs)
}
```

---

## The bigger the interface, the weaker the abstraction.

!!! quote ""
    Small interfaces are more reusable. `io.Reader` (1 method) fits almost anywhere.
    A large interface narrows what can implement it. Design interfaces around what you **consume**, not what you **provide**.

```go
// ✓ Small, powerful, composable
type Reader interface { Read(p []byte) (n int, err error) }
type Writer interface { Write(p []byte) (n int, err error) }
type ReadWriter interface { Reader; Writer }

// ✗ Brittle, hard to satisfy, low reuse
type UserServiceInterface interface {
    GetUser(id int) (*User, error)
    CreateUser(u *User) error
    UpdateUser(u *User) error
    DeleteUser(id int) error
    ListUsers(filter Filter) ([]*User, error)
    AuthenticateUser(email, password string) (string, error)
    // ... 10 more methods
}
```

---

## Accept interfaces, return structs.

!!! quote ""
    Functions should accept the smallest interface that satisfies their needs — maximizing caller flexibility.
    Return concrete types so callers can access the full API without type assertions.

```go
// ✓ Accept io.Reader; return concrete *Config
func ParseConfig(r io.Reader) (*Config, error) { ... }

// Callers can pass: os.File, bytes.Buffer, strings.Reader, http.Response.Body, ...
// All satisfy io.Reader without knowing about ParseConfig.
```

---

## Make the zero value useful.

!!! quote ""
    Design your types so the zero value is ready to use without initialization.
    This reduces the burden on callers and eliminates a class of "forgot to call Init()" bugs.

```go
// sync.Mutex: zero value is an unlocked mutex
var mu sync.Mutex  // ready to Lock() immediately

// bytes.Buffer: zero value is an empty buffer
var buf bytes.Buffer
buf.WriteString("hello") // no NewBuffer() needed

// Your own type:
type RateLimiter struct {
    mu       sync.Mutex
    requests []time.Time
    limit    int // zero = unlimited (a useful default!)
}
```

---

## A little copying is better than a little dependency.

!!! quote ""
    Adding a dependency has real costs: build time, version conflicts, security surface, transitive deps.
    For a 10-line utility function, copying is often the right call.

```go
// Rather than importing "github.com/some/pkg" for one helper:
func containsString(slice []string, s string) bool {
    for _, v := range slice {
        if v == s { return true }
    }
    return false
}
// No import. No dependency. Nothing to go wrong.
```

---

## Clear is better than clever.

!!! quote ""
    Go celebrates readable, boring code. A clever solution that requires deep knowledge to understand
    is a maintenance liability. Write the obvious thing — future readers (including you) will be grateful.

=== "✗ Clever"
    ```go
    flag ^= 1          // toggle bool stored as int
    x, y = y, x^y^x   // swap without temp variable
    ```

=== "✓ Clear"
    ```go
    flag = !flag       // obvious intent
    x, y = y, x        // Go supports this natively
    ```

---

## Errors are values.

!!! quote ""
    Because errors are just values, you can program with them: store them in structs,
    wrap them for context, filter them, count them, or pass them through channels.
    Don't just check errors — *handle* them thoughtfully.

```go
// Errors stored in a struct — accumulate without short-circuiting
type MultiError struct{ errs []error }
func (m *MultiError) Add(err error) { if err != nil { m.errs = append(m.errs, err) } }
func (m *MultiError) Err() error {
    if len(m.errs) == 0 { return nil }
    return m
}
func (m *MultiError) Error() string { return fmt.Sprintf("%v", m.errs) }
```

---

## Don't just check errors, handle them gracefully.

!!! quote ""
    Checking `if err != nil { return err }` is fine, but think about what the caller needs.
    Can you recover? Add context? Retry? Log once at the boundary?

```go
// ✓ Wrap with context so the caller knows where it came from
func loadUser(id int) (*User, error) {
    row, err := db.QueryRow("SELECT * FROM users WHERE id=?", id)
    if err != nil {
        return nil, fmt.Errorf("loadUser(%d): %w", id, err)
    }
    ...
}
```

---

## Syscall must always be guarded with build tags.

!!! quote ""
    System calls are OS-specific. Code using `syscall` or `golang.org/x/sys` must use build
    constraints so it only compiles on the intended platform.

```go
//go:build linux

package main

import "golang.org/x/sys/unix"

func getRlimit() unix.Rlimit {
    var r unix.Rlimit
    unix.Getrlimit(unix.RLIMIT_NOFILE, &r)
    return r
}
```

---

## Documentation is for users.

!!! quote ""
    Comments on exported identifiers are part of the API. Write them for the *user* of your
    package, not the implementer. Every exported function, type, and package should have a
    doc comment starting with the identifier's name.

```go
// Package cache implements a time-limited in-memory key-value cache.
// Keys expire after their TTL elapses; expired entries are collected lazily.
package cache

// Set stores the value under key with the given TTL.
// It replaces any existing value. TTL must be positive.
func (c *Cache) Set(key string, value any, ttl time.Duration) { ... }
```
