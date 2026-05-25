# Language Basics

Every Go file belongs to a **package**. Execution starts in `package main`'s `main()` function.
Imports are explicit — unused imports are **compile errors**. Go forces intentionality.

```go
package main

import (
    "fmt"
    "math/rand"
)

func main() {
    fmt.Println("Hello, Go")
    fmt.Println(rand.Intn(100))
}
```

## Variables & Types

Go has two ways to declare variables. `var` is explicit and works at package scope; `:=` is short-form declaration + inference, available only inside functions.

```go
// Explicit — usable at package level
var name string = "gopher"
var count int    // zero value: 0

// Short declaration — function scope only
age := 42
x, y := 10, 20  // multiple assignment

// Constants — evaluated at compile time
const Pi = 3.14159
const (
    KB = 1024
    MB = 1024 * KB
)
```

### Built-in Types

| Category | Types | Notes |
|----------|-------|-------|
| Integers | `int int8 int16 int32 int64`<br>`uint uint8 uint16 uint32 uint64` | `int` is platform-sized (32 or 64 bit) |
| Floats | `float32 float64` | Default float literal is `float64` |
| String | `string` | Immutable UTF-8 bytes; `len(s)` = **byte** count |
| Boolean | `bool` | Only `true` / `false`; no truthy coercions |
| Aliases | `byte` = `uint8`, `rune` = `int32` | `rune` represents a Unicode code point |

## Control Flow

Go has **one loop keyword** — `for`. It handles while-style, C-style, and range iteration.

```go
// C-style
for i := 0; i < 10; i++ { ... }

// While-style
for condition { ... }

// Infinite loop
for { ... }

// Range over slice, string, map, channel
for i, v := range slice { ... }
for k, v := range myMap { ... }

// Range over string yields runes (Unicode), not bytes
for i, ch := range "héllo" {
    fmt.Printf("%d: %c\n", i, ch)
}
```

!!! warning "Range over strings"
    When ranging over a `string`, the index is the **byte** position, not the character position.
    Multi-byte Unicode characters (like `é`) will skip byte indices.
    Use `[]rune(s)` if you need character-indexed access.

```go
// If — init statement is optional, no parentheses required
if err := doSomething(); err != nil {
    return err
}

// Switch — no fallthrough by default
switch os := runtime.GOOS; os {
case "darwin":
    fmt.Println("macOS")
case "linux":
    fmt.Println("Linux")
default:
    fmt.Println(os)
}

// Tagless switch — cleaner if-else chain
switch {
case x < 0:
    fmt.Println("negative")
case x == 0:
    fmt.Println("zero")
default:
    fmt.Println("positive")
}
```

## Pointers

Go has pointers but **no pointer arithmetic**. They're used to share data or allow mutation inside functions.

```go
x := 42
p := &x         // p is *int; &x takes the address of x
fmt.Println(*p) // dereference: 42
*p = 100        // x is now 100

// new() allocates zeroed memory and returns a pointer
p2 := new(int)  // *p2 == 0

// Go does NOT have pointer arithmetic — p++ is a compile error
```

!!! tip "When to use pointer receivers"
    Use a **pointer receiver** (`func (s *S) Foo()`) when the method needs to mutate the receiver,
    or when the struct is large (to avoid copying). Use a **value receiver** when the method only
    reads data and the struct is small. Be consistent — don't mix pointer and value receivers on
    the same type.
