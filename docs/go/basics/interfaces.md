# Interfaces

Interfaces in Go are **implicit** — a type satisfies an interface simply by having the required methods.
No `implements` keyword. This is called *structural typing*.

```go
type Writer interface {
    Write(p []byte) (n int, err error)
}

// Any type with a matching Write method satisfies Writer —
// os.File, bytes.Buffer, net.Conn all qualify without knowing about it.

type Stringer interface {
    String() string
}

// Your type automatically satisfies fmt.Stringer:
type Color int
const (Red Color = iota; Green; Blue)

func (c Color) String() string {
    return [...]string{"Red", "Green", "Blue"}[c]
}
fmt.Println(Red) // "Red" — fmt calls String() automatically
```

## Design Principles

!!! quote "Go Proverb"
    *"The bigger the interface, the weaker the abstraction."*

    Small interfaces are more reusable. `io.Reader` (1 method) fits almost anywhere.
    A large interface narrows what can implement it. Design interfaces around what you **consume**.

!!! quote "Go Proverb"
    *"Accept interfaces, return structs."*

    Functions should accept the smallest interface that satisfies their needs — maximizing
    caller flexibility. Return concrete types so callers can access the full API without casting.

```go
// ✓ Idiomatic: accept io.Reader (1-method interface), return concrete *Result
func Parse(r io.Reader) (*Result, error) { ... }

// ✗ Avoid: accepting or returning your own large interfaces
func Process(svc MyHugeServiceInterface) MyHugeServiceInterface { ... }
```

## The nil Interface Trap

An interface value has two hidden fields: a **type** and a **value pointer**.
An interface is only `nil` when **both** are nil. This causes one of Go's most notorious bugs.

!!! danger "nil != nil — the interface nil trap"
    Returning a typed nil pointer from a function with an interface return type looks nil — but isn't.
    The `== nil` check on the returned interface will be `false`.

```go
type MyError struct{ msg string }
func (e *MyError) Error() string { return e.msg }

// ✗ BUG: wraps a nil *MyError inside an interface — not nil!
func getError() error {
    var p *MyError = nil
    return p // interface{type=*MyError, value=nil} — NOT nil!
}

err := getError()
fmt.Println(err == nil) // false — surprise!

// ✓ Fix: return the untyped nil directly
func getError() error {
    return nil // interface{type=nil, value=nil} — truly nil
}

// ✓ Pattern: only create the concrete type when there's an actual error
func mayFail(fail bool) error {
    if fail {
        return &MyError{"oops"}
    }
    return nil // untyped nil
}
```

## Type Assertions & Type Switches

```go
var i interface{} = "hello"

// Type assertion — panics if the type is wrong
s := i.(string)       // s = "hello"

// Safe assertion — comma-ok pattern (never panics)
s, ok := i.(string)   // ok = true
n, ok := i.(int)      // ok = false, n = 0

// Type switch — dispatches on the dynamic type
switch v := i.(type) {
case string:
    fmt.Println("string:", v)
case int:
    fmt.Println("int:", v)
case nil:
    fmt.Println("nil")
default:
    fmt.Printf("unknown type: %T\n", v)
}
```

## Empty Interface

`any` (alias for `interface{}`) accepts all values. Use it sparingly — you lose type safety and need type assertions to do anything useful.

```go
func printAnything(v any) {
    fmt.Println(v) // fmt knows how to handle any
}

// Prefer generics (Go 1.18+) when the operation is type-agnostic:
func Map[T, U any](s []T, f func(T) U) []U { ... }
```
