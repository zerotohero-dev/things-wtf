# unsafe

The `unsafe` package bypasses Go's type safety and memory model. The compiler gives **no guarantees** when you use it. Code using `unsafe` may break silently with any Go release. Use it only at true boundaries — FFI, binary protocols, performance-critical reflection.

!!! quote "Go Proverb"
    *"With the unsafe package there are no guarantees."*

## What unsafe Provides

```go
import "unsafe"

// Size, alignment, and field offset information
var x int32
unsafe.Sizeof(x)               // 4 — bytes of x's type
unsafe.Alignof(x)              // 4 — alignment requirement
unsafe.Offsetof(myStruct.field) // byte offset of field within struct

// unsafe.Pointer — a raw pointer that defeats the type system
// Convertible to/from any *T or uintptr
```

## The Six Legal Patterns

The Go spec defines exactly six safe uses of `unsafe.Pointer`. Everything else is undefined behavior.

### Pattern 1 — Reinterpret a value as a different type

Both types must have the same memory size. Classic use: accessing the raw bits of a float.

```go
func float64bits(f float64) uint64 {
    return *(*uint64)(unsafe.Pointer(&f))
}

func float64frombits(b uint64) float64 {
    return *(*float64)(unsafe.Pointer(&b))
}

// Inspect the IEEE 754 representation:
bits := float64bits(1.0)
fmt.Printf("%064b\n", bits) // 0011111111110000...
```

### Pattern 2 — String ↔ []byte without allocation

Strings and slices share the same underlying layout. This avoids the copy that `[]byte(s)` and `string(b)` would perform.

```go
// Zero-copy string → []byte (READ ONLY — must not modify the result)
func stringToBytes(s string) []byte {
    return unsafe.Slice(unsafe.StringData(s), len(s))
}

// Zero-copy []byte → string
func bytesToString(b []byte) string {
    return unsafe.String(unsafe.SliceData(b), len(b))
}
```

!!! danger "The resulting []byte MUST NOT be modified"
    Strings in Go are immutable. If you modify the `[]byte` returned by `stringToBytes`,
    you corrupt the original string — which may be interned or shared in unpredictable ways.

### Pattern 3 — Access struct fields via pointer arithmetic

```go
type Header struct {
    Version uint8
    Flags   uint16
    Length  uint32
}

h := Header{Version: 1, Flags: 0x0A, Length: 256}

// Access Flags field by offset
flagsPtr := (*uint16)(unsafe.Pointer(
    uintptr(unsafe.Pointer(&h)) + unsafe.Offsetof(h.Flags),
))
fmt.Println(*flagsPtr) // 10
```

### Pattern 4 — Convert between pointer types via Pointer

```go
// Convert *[4]byte to *uint32 to read 4 bytes as a single integer
var buf [4]byte = [4]byte{0x01, 0x02, 0x03, 0x04}
n := *(*uint32)(unsafe.Pointer(&buf))
fmt.Printf("%08x\n", n) // 04030201 (little-endian on x86)
```

### Pattern 5 — Reflect SliceHeader / StringHeader (legacy)

Pre-Go 1.17 code used `reflect.SliceHeader` and `reflect.StringHeader`. The modern replacements are `unsafe.Slice`, `unsafe.SliceData`, `unsafe.String`, and `unsafe.StringData` (Go 1.17+).

```go
// Modern (Go 1.17+) — preferred
s := "hello"
ptr  := unsafe.StringData(s) // *byte pointing to s's first byte
data := unsafe.Slice(ptr, len(s)) // []byte sharing s's backing memory

// Legacy (pre-1.17) — still compiles but avoid in new code
sh := (*reflect.StringHeader)(unsafe.Pointer(&s))
```

### Pattern 6 — Conversion through uintptr in a single expression

The **only** safe way to do pointer arithmetic — the entire operation must be a single expression so the GC cannot run between steps.

```go
// ✓ Safe: single expression, GC cannot interrupt
p := (*int)(unsafe.Pointer(uintptr(unsafe.Pointer(&s)) + unsafe.Offsetof(s.field)))

// ✗ UNSAFE: uintptr stored in a variable
u := uintptr(unsafe.Pointer(&s)) // GC may run here; s may be moved or collected
p := (*int)(unsafe.Pointer(u))    // u may now be a dangling pointer
```

## The uintptr Trap

!!! danger "uintptr is NOT a pointer — the GC does not trace it"
    Once you convert a pointer to `uintptr`, the garbage collector forgets about it.
    If the object has no other live references, it may be collected.
    In a future moving GC, the object's address may change.
    **Never store a pointer as `uintptr` across a GC-safe point (function call, channel op, etc.).**

```go
// ✗ BUG: uintptr stored across a potential GC point
func broken(s *MyStruct) *int {
    u := uintptr(unsafe.Pointer(s))  // line 1
    // ... any function call here could trigger GC ...
    return (*int)(unsafe.Pointer(u)) // u may be stale
}

// ✓ Safe: compute in one expression
func safe(s *MyStruct) *int {
    return (*int)(unsafe.Pointer(
        uintptr(unsafe.Pointer(s)) + unsafe.Offsetof(s.field),
    ))
}
```

## Struct Alignment for atomic Operations

64-bit atomic operations (`atomic.AddInt64`, etc.) require the value to be **8-byte aligned**. On 32-bit platforms, heap allocations are only 4-byte aligned, so struct fields may not be.

```go
// ✓ Guarantee alignment: put int64 fields FIRST in the struct
type Counter struct {
    count int64  // first field — always 8-byte aligned
    name  string
}
// atomic.AddInt64(&c.count, 1) is safe on all platforms

// ✗ Fragile: int64 after other fields may not be aligned on 32-bit
type BadCounter struct {
    name  string
    count int64  // not guaranteed 8-byte aligned on 32-bit
}
```

## cgo — Calling C from Go

`cgo` is another boundary where type safety weakens. It lets Go call C functions and vice versa.

```go
// Comments directly above "import C" become C source code
// #include <string.h>
// #include <stdlib.h>
import "C"
import "unsafe"

func copyString(s string) *C.char {
    cs := C.CString(s)         // allocates C memory — must be freed
    defer C.free(unsafe.Pointer(cs))
    return C.strdup(cs)
}
```

!!! warning "cgo rules"
    - C memory must be freed manually — the Go GC does not manage it
    - Go pointers passed to C must not be stored by C beyond the call
    - cgo adds significant build complexity and disables cross-compilation by default
    - Disable with `CGO_ENABLED=0` for fully static, cross-compiled binaries

```sh
# Static binary, no C dependencies
CGO_ENABLED=0 go build -o myapp .

# Cross-compile for Linux from macOS
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o myapp-linux .
```

## Summary

| Use case | Pattern | Notes |
|----------|---------|-------|
| Inspect float bits | Reinterpret via `*(*uint64)(unsafe.Pointer(&f))` | Types must be same size |
| Zero-copy string↔[]byte | `unsafe.Slice` / `unsafe.String` | Never mutate string-backed bytes |
| Struct field access | `uintptr` + `unsafe.Offsetof` in single expression | Never store intermediate `uintptr` |
| int64 alignment | Put int64 first in struct | Critical for 32-bit atomic safety |
| C interop | cgo | Adds build complexity; disable with `CGO_ENABLED=0` |
