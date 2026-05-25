# Gotchas

The sharpest edges in Go — things that will bite you if you don't know about them.

---

## 1. Goroutine Leaks

Goroutines are cheap but not free. A goroutine blocked forever on a channel or waiting for a resource that never arrives is leaked memory and a CPU ghost.

!!! danger "Always give goroutines a way to stop"
    Every goroutine you launch should have a clear stopping condition — a context cancellation, a done channel, or channel close. Uncontrolled goroutine growth is a memory leak unique to Go.

=== "✗ Leaking goroutine"
    ```go
    func leak() {
        ch := make(chan int)
        go func() {
            val := <-ch // blocks forever if nobody sends
            process(val)
        }()
        // ch goes out of scope; goroutine is stuck forever
    }
    ```

=== "✓ Context cancellation"
    ```go
    func withContext(ctx context.Context) {
        ch := make(chan int)
        go func() {
            select {
            case val := <-ch:
                process(val)
            case <-ctx.Done():
                return // clean exit when context is cancelled
            }
        }()
    }
    ```

---

## 2. for-range Copies Values

The range variable is a **copy** of the element. Modifying it doesn't affect the original slice.

=== "✗ Modifying the copy"
    ```go
    type Point struct{ X, Y int }
    points := []Point{{1,2}, {3,4}}

    for _, p := range points {
        p.X *= 2  // modifies the copy — points is unchanged
    }
    ```

=== "✓ Use index"
    ```go
    for i := range points {
        points[i].X *= 2  // modifies in place
    }
    ```

=== "✓ Pointer slice"
    ```go
    ptrPoints := []*Point{{1,2}, {3,4}}
    for _, p := range ptrPoints {
        p.X *= 2  // p is a pointer — *p is modified
    }
    ```

---

## 3. Append and Slice Sharing

When a slice has remaining capacity, `append` extends it **in place** — silently modifying the original.

```go
a := make([]int, 3, 6) // len=3, cap=6
b := a[0:3]            // shares a's backing array

b = append(b, 99)      // cap > len — no reallocation
                       // b[3] = 99 ... which is a[3] = 99
fmt.Println(a[:4])     // [0 0 0 99] — a was silently modified!

// Protection: use 3-index slice to force reallocation
b = a[0:3:3]           // cap=3
b = append(b, 99)      // must allocate — a is safe
```

---

## 4. Shadowed `err` in Short Declarations

`:=` in an inner block creates a **new** variable — it does not reuse the outer one.

```go
func example() error {
    data, err := os.ReadFile("a.txt")
    if err != nil { return err }

    if someCondition {
        result, err := process(data) // NEW err — shadows outer err!
        if err != nil { return err }
        _ = result
    }

    return err // outer err from ReadFile — always nil here if we got past line 2
}

// ✓ Fix: assign with = once declared
func example() error {
    data, err := os.ReadFile("a.txt")
    if err != nil { return err }
    var result []byte
    result, err = process(data)  // reuses existing err
    if err != nil { return err }
    _ = result
    return nil
}
```

---

## 5. Defer in a Loop

Deferred calls run when the **function** returns, not at the end of each loop iteration.

See the full explanation with fixes in [Defer, Panic & Recover](../basics/defer.md#defer-in-loops).

---

## 6. String Is Not a `[]byte`

`len(s)` returns **bytes**, not characters. Multi-byte Unicode characters span multiple indices.

```go
s := "héllo"
fmt.Println(len(s))     // 6 bytes, not 5 characters (é = 2 bytes)
fmt.Println(s[1])       // 195 — a raw byte, not 'é'

// ✓ Iterate correctly over Unicode
for i, r := range s {
    fmt.Printf("byte index %d: %c\n", i, r)
}

// ✓ Character count
runes := []rune(s)
fmt.Println(len(runes)) // 5
```

---

## 7. Mutexes Must Not Be Copied

Copying a `sync.Mutex` copies its internal state — the copy and the original become independent locks.

!!! danger "go vet catches this"
    `go vet` will report mutex copies. Ensure any struct containing a mutex is always passed and stored by pointer.

```go
type SafeCounter struct {
    mu    sync.Mutex
    count int
}

// ✗ Value receiver copies the mutex — broken
func bad(c SafeCounter) {
    c.mu.Lock() // locks a copy; original mutex unaffected
}

// ✓ Pointer receiver
func (c *SafeCounter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}
```

---

## 8. The nil Interface Trap

Returning a typed nil pointer from an `error`-returning function looks nil — but isn't.

See full explanation with fixes in [Interfaces — The nil Interface Trap](../basics/interfaces.md#the-nil-interface-trap).

---

## 9. Comparing Structs

Structs are comparable with `==` only if **all their fields** are comparable. Slices, maps, and functions are not comparable.

```go
type Good struct{ A, B int }
g1 := Good{1, 2}
g2 := Good{1, 2}
fmt.Println(g1 == g2) // true ✓

type Bad struct {
    Data []int // slices are not comparable
}
b1 := Bad{[]int{1}}
// b1 == b1 → compile error: invalid operation
```

Use `reflect.DeepEqual` or write a custom `Equal` method for non-comparable structs.

---

## Quick Reference

| Gotcha | Key | Fix |
|--------|-----|-----|
| Goroutine leak | No stopping condition | Use context or done channel |
| Range copy | `for _, v := range s` copies `v` | Use `s[i]` or pointer slice |
| Append aliasing | Sub-slice shares backing array | 3-index slice or `copy` |
| Shadowed `err` | `:=` in inner block creates new var | Use `=` for re-assignments |
| Defer in loop | Defers pile up until function returns | Wrap iteration in a closure |
| nil interface | `(*T)(nil) != nil` when wrapped | Return untyped `nil` from `error` functions |
| Mutex copy | Copy splits the lock | Always use pointer receiver with mutex |
