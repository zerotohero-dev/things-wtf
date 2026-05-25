# Closures

A closure is a function that **captures variables from its surrounding scope by reference**, not by value.

```go
func makeCounter() func() int {
    n := 0
    return func() int {
        n++   // captures n by reference — same n each call
        return n
    }
}

c := makeCounter()
fmt.Println(c()) // 1
fmt.Println(c()) // 2
fmt.Println(c()) // 3

// Each call to makeCounter() creates an independent n
c2 := makeCounter()
fmt.Println(c2()) // 1 — unaffected by c
```

## The Loop-Closure Bug

Before Go 1.22, loop variables were **shared across all iterations**. All closures captured the
same variable, so by the time they ran (e.g., when goroutines were scheduled), the loop had
finished and the variable held its final value.

**Go 1.22 fixed this** — loop variables are now per-iteration for `range` loops. But you'll encounter
older code with workarounds, and the issue still applies to goroutines launched inside loops where
you can't guarantee execution order.

!!! warning "Loop-closure bug (pre-Go 1.22)"
    All goroutines share the same `i` variable. By the time they run, the loop is done.

=== "✗ Bug (pre-1.22)"
    ```go
    // All goroutines print 3 — they share the same i
    for i := 0; i < 3; i++ {
        go func() {
            fmt.Println(i) // captures the loop variable
        }()
    }
    // Output: 3 3 3  (order varies, value is always 3)
    ```

=== "✓ Fix — shadow the variable"
    ```go
    // Works in all Go versions
    for i := 0; i < 3; i++ {
        i := i // shadow: creates a new variable per iteration
        go func() {
            fmt.Println(i) // captures its own i
        }()
    }
    // Output: 0 1 2  (order varies, values are correct)
    ```

=== "✓ Fix — pass as argument"
    ```go
    // Explicit is clearest
    for i := 0; i < 3; i++ {
        go func(id int) {
            fmt.Println(id)
        }(i) // i copied into id at call time
    }
    ```

## Closures for State

Closures are a lightweight alternative to single-method objects:

```go
// Memoization via closure
func memoize(fn func(int) int) func(int) int {
    cache := map[int]int{}
    return func(n int) int {
        if v, ok := cache[n]; ok {
            return v
        }
        v := fn(n)
        cache[n] = v
        return v
    }
}

slowSquare := func(n int) int {
    time.Sleep(100 * time.Millisecond)
    return n * n
}
fastSquare := memoize(slowSquare)
fastSquare(5) // slow first time
fastSquare(5) // instant — from cache
```
