# Zero Values

Every type in Go has a **zero value** — the value it holds when declared but not assigned.
This is a deliberate design choice: no uninitialized memory surprises.

| Type | Zero Value |
|------|-----------|
| `int`, `float64`, etc. | `0` |
| `string` | `""` |
| `bool` | `false` |
| pointer, slice, map, chan, func, interface | `nil` |
| struct | all fields zero-valued recursively |

## Make the Zero Value Useful

!!! quote "Go Proverb"
    *"Make the zero value useful."*

    Design your types so the zero value is ready to use without calling an initializer.
    `sync.Mutex` is the canonical example — a zero `Mutex` is an unlocked mutex, ready to go.

```go
// sync.Mutex works as zero value — no NewMutex()
var mu sync.Mutex
mu.Lock()
defer mu.Unlock()

// bytes.Buffer works as zero value
var buf bytes.Buffer
buf.WriteString("hello") // no need for bytes.NewBuffer()
```

### Designing for zero values

```go
// Logger with a sensible zero value:
// out == nil means "use stderr"
type Logger struct {
    prefix string
    out    io.Writer
}

func (l *Logger) Log(msg string) {
    out := l.out
    if out == nil {
        out = os.Stderr // sensible default when zero
    }
    fmt.Fprintln(out, l.prefix, msg)
}

// Callers can use it with no initialization:
var log Logger
log.Log("starting up") // writes to stderr

// Or customize:
log := Logger{prefix: "[app]", out: logFile}
```

## The Nil Map Trap

!!! danger "nil map write = panic"
    A nil **slice** is safe to append to.
    A nil **map** is safe to **read** from (returns zero value).
    But **writing to a nil map panics**. Always initialize maps before writing.

```go
var s []int
s = append(s, 1)  // ✓ fine — append handles nil slice

var m map[string]int
_ = m["key"]      // ✓ fine — returns 0, no panic
m["key"] = 1      // ✗ PANIC: assignment to entry in nil map

// Fix: initialize first
m = make(map[string]int)
m["key"] = 1      // ✓ fine
```
