# Defer, Panic & Recover

## Defer

`defer` schedules a function call to run **when the surrounding function returns** — regardless of how (normal return, error, or panic). Deferred calls run in **LIFO** order.

```go
// Classic use: pair resource acquisition with cleanup
func copyFile(src, dst string) error {
    f, err := os.Open(src)
    if err != nil { return err }
    defer f.Close()       // runs when copyFile returns

    out, err := os.Create(dst)
    if err != nil { return err }
    defer out.Close()     // runs before f.Close() (LIFO)

    _, err = io.Copy(out, f)
    return err
}

// defer + mutex: guaranteed unlock
mu.Lock()
defer mu.Unlock()
```

### Argument Evaluation

Defer captures argument **values immediately**, but runs the call later.

```go
x := 10
defer fmt.Println(x)  // argument x=10 captured NOW
x = 20
// At function return: prints "10", not "20"

// But method receivers and closure variables are evaluated at call time:
defer func() {
    fmt.Println(x) // x evaluated when defer runs — prints "20"
}()
```

### Defer in Loops

!!! danger "Defer inside a loop"
    Defers accumulate until the **function** returns — not each iteration.
    Opening a file and deferring `Close()` in a loop will hold all handles open until the function exits.

=== "✗ Accumulates handles"
    ```go
    func processFiles(paths []string) error {
        for _, p := range paths {
            f, err := os.Open(p)
            if err != nil { return err }
            defer f.Close() // held open until processFiles returns!
            process(f)
        }
        return nil
    }
    ```

=== "✓ Wrap in a closure"
    ```go
    func processFiles(paths []string) error {
        for _, p := range paths {
            if err := func() error {
                f, err := os.Open(p)
                if err != nil { return err }
                defer f.Close() // closes when this lambda returns
                return process(f)
            }(); err != nil {
                return err
            }
        }
        return nil
    }
    ```

## Panic & Recover

`panic` unwinds the stack, running deferred functions along the way. `recover` inside a deferred function can catch a panic and resume normal execution.

!!! tip "Panic vs. error rule"
    **Panic** when the program is in an impossible state — a programmer bug.
    **Return errors** for expected failure conditions (file not found, bad input, network error).
    Library code should almost never panic; let the caller decide what's fatal.

```go
// panic: unrecoverable programmer errors
func mustPositive(n int) int {
    if n <= 0 {
        panic(fmt.Sprintf("expected positive, got %d", n))
    }
    return n
}

// recover: convert panic to error at package/server boundaries
func safeRun(fn func()) (err error) {
    defer func() {
        if r := recover(); r != nil {
            err = fmt.Errorf("panic: %v", r)
        }
    }()
    fn()
    return nil
}

// HTTP server recovery middleware — prevents one handler from crashing everything
func recoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if r := recover(); r != nil {
                log.Printf("panic recovered: %v\n%s", r, debug.Stack())
                http.Error(w, "Internal Server Error", 500)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```
