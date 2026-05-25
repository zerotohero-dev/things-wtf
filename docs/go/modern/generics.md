# Generics

Generics (Go 1.18+) allow writing functions and types parameterized over types. They enable type-safe reuse without `interface{}` boxing or code generation.

## Basic Syntax

Type parameters are declared in **square brackets** before the argument list.

```go
// Generic function
func Map[T, U any](s []T, f func(T) U) []U {
    result := make([]U, len(s))
    for i, v := range s {
        result[i] = f(v)
    }
    return result
}

// Type is inferred from arguments — no need to specify
doubled := Map([]int{1, 2, 3}, func(n int) int { return n * 2 })
// [2 4 6]

upper := Map([]string{"a", "b"}, strings.ToUpper)
// ["A" "B"]
```

## Generic Types

```go
// Generic stack
type Stack[T any] struct {
    items []T
}

func (s *Stack[T]) Push(v T) {
    s.items = append(s.items, v)
}

func (s *Stack[T]) Pop() (T, bool) {
    if len(s.items) == 0 {
        var zero T      // zero value of T
        return zero, false
    }
    n := len(s.items) - 1
    v := s.items[n]
    s.items = s.items[:n]
    return v, true
}

func (s *Stack[T]) Len() int { return len(s.items) }

// Usage — type inferred
var s Stack[string]
s.Push("hello")
s.Push("world")
v, _ := s.Pop() // "world"
```

## Constraints

Constraints define what operations are allowed on a type parameter. They are **interfaces** — but can include type sets with `~`.

### any and comparable

```go
// any: no constraint — only operations valid on all types (assignment, ==nil for pointers)
func Ptr[T any](v T) *T { return &v }

// comparable: types that support == and != (required for map keys)
func Contains[T comparable](s []T, target T) bool {
    for _, v := range s {
        if v == target { return true }
    }
    return false
}

// Generic set backed by a map
type Set[T comparable] map[T]struct{}

func (s Set[T]) Add(v T)       { s[v] = struct{}{} }
func (s Set[T]) Has(v T) bool  { _, ok := s[v]; return ok }
func (s Set[T]) Delete(v T)    { delete(s, v) }
```

### Type Sets with `~`

The `~` prefix means "any type whose **underlying type** is T". This allows custom named types to satisfy the constraint.

```go
type Celsius    float64
type Fahrenheit float64

// Without ~: only float64 satisfies Float
// With ~: Celsius, Fahrenheit, and float64 all satisfy Float
type Float interface {
    ~float32 | ~float64
}

func Sum[T Float](s []T) T {
    var total T
    for _, v := range s { total += v }
    return total
}

temps := []Celsius{98.6, 37.0, 100.0}
Sum(temps) // ✓ works because ~float64 matches Celsius's underlying type
```

### The `constraints` Package

```go
import "golang.org/x/exp/constraints"

// Ordered: all types supporting <, >, <=, >=
// Includes all int, float, and string types (and their named variants via ~)
func Min[T constraints.Ordered](a, b T) T {
    if a < b { return a }
    return b
}

func Max[T constraints.Ordered](a, b T) T {
    if a > b { return a }
    return b
}

func Clamp[T constraints.Ordered](v, lo, hi T) T {
    return Min(Max(v, lo), hi)
}
```

### Constraints with Methods

```go
type Stringer interface {
    String() string
}

// Accepts anything that has a String() method
func StringAll[T Stringer](items []T) []string {
    result := make([]string, len(items))
    for i, v := range items {
        result[i] = v.String()
    }
    return result
}

// Combining type set + method
type NumericStringer interface {
    ~int | ~float64
    String() string
}
```

## Common Generic Utilities

```go
// Filter
func Filter[T any](s []T, keep func(T) bool) []T {
    var out []T
    for _, v := range s {
        if keep(v) { out = append(out, v) }
    }
    return out
}

// Reduce
func Reduce[T, U any](s []T, init U, fn func(U, T) U) U {
    acc := init
    for _, v := range s { acc = fn(acc, v) }
    return acc
}

// Keys and Values from a map
func Keys[K comparable, V any](m map[K]V) []K {
    keys := make([]K, 0, len(m))
    for k := range m { keys = append(keys, k) }
    return keys
}

func Values[K comparable, V any](m map[K]V) []V {
    vals := make([]V, 0, len(m))
    for _, v := range m { vals = append(vals, v) }
    return vals
}

// Must — panic on error (for init paths)
func Must[T any](v T, err error) T {
    if err != nil { panic(err) }
    return v
}
// Usage:
db := Must(sql.Open("pgx", dsn))
```

## When to Use Generics

!!! tip "Good candidates"
    - **Data structures**: stacks, queues, trees, sets, ordered maps
    - **Slice/map utilities**: Map, Filter, Reduce, Contains, Keys, Values
    - **Eliminating duplicate code** where the same algorithm is written for multiple concrete types
    - **Type-safe wrappers** around `any` APIs (e.g., a typed cache)

!!! warning "When NOT to use generics"

    **When `any` interface already works:**
    ```go
    // ✗ Unnecessary generic — fmt.Println accepts any already
    func Print[T any](v T) { fmt.Println(v) }

    // ✓ Just use any
    func Print(v any) { fmt.Println(v) }
    ```

    **When you actually need interface dispatch (behavior varies by type):**
    ```go
    // ✗ Generic doesn't help here — we need polymorphism
    func Serialize[T any](v T) []byte { ... } // how do you serialize without knowing T?

    // ✓ Interface lets the value provide its own serialization
    type Serializable interface { Serialize() []byte }
    func Serialize(v Serializable) []byte { return v.Serialize() }
    ```

    **When there's only one instantiation:**
    ```go
    // ✗ Generic for one use — adds complexity with no reuse benefit
    func processUsers[T User](items []T) { ... }

    // ✓ Just use the concrete type
    func processUsers(items []User) { ... }
    ```

## Type Inference

Go infers type parameters from function arguments in most cases. Explicit specification is needed when inference is ambiguous.

```go
// Inferred — T=string, U=int
lengths := Map([]string{"a", "bb", "ccc"}, func(s string) int { return len(s) })

// Explicit — needed when return type can't be inferred from args
func Zero[T any]() T { var z T; return z }
n := Zero[int]()    // explicit: T cannot be inferred from arguments alone

// Partially explicit (rare)
result := SomeFunc[int](someArg)
```

## Limitations (as of Go 1.22)

- No **method-level** type parameters — only function and type level
- No **specialization** — no way to have different behavior for specific types within a generic function
- No **variadic type parameters** — can't write `func Zip[T ...any](...)`
- Type inference has gaps — sometimes you must be explicit

```go
// ✗ Not allowed: method with its own type parameter
type Container[T any] struct{ ... }
func (c Container[T]) As[U any]() U { ... } // compile error

// ✓ Workaround: top-level function
func As[T, U any](c Container[T]) U { ... }
```
