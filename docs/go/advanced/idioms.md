# Idiomatic Patterns

Common design patterns that experienced Go developers reach for. These aren't frameworks — they're idioms that emerge naturally from Go's design.

## Functional Options

When constructors have many optional parameters, use **functional options** instead of long argument lists or builder objects. The pattern is extensible and backward-compatible — new options can be added without changing the function signature.

```go
type Server struct {
    host    string
    port    int
    timeout time.Duration
    maxConn int
}

// Each option is a function that modifies a Server
type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}
func WithMaxConn(n int) Option {
    return func(s *Server) { s.maxConn = n }
}
func WithTLS(cert, key string) Option {
    return func(s *Server) { /* configure TLS */ }
}

// Constructor applies defaults, then each option
func NewServer(host string, port int, opts ...Option) *Server {
    s := &Server{
        host:    host,
        port:    port,
        timeout: 30 * time.Second, // sensible default
        maxConn: 100,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Caller code is clean and self-documenting:
srv := NewServer("localhost", 8080,
    WithTimeout(10 * time.Second),
    WithMaxConn(500),
    WithTLS("cert.pem", "key.pem"),
)
```

## Table-Driven Tests

Go's testing idiom. A slice of test cases makes adding new cases trivial and keeps failure messages informative.

```go
func TestDivide(t *testing.T) {
    tests := []struct {
        name    string
        a, b    float64
        want    float64
        wantErr bool
    }{
        {"positive", 10, 2, 5, false},
        {"negative", -6, 3, -2, false},
        {"zero divisor", 5, 0, 0, true},
        {"zero dividend", 0, 5, 0, false},
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            got, err := divide(tc.a, tc.b)
            if (err != nil) != tc.wantErr {
                t.Fatalf("wantErr=%v, got err=%v", tc.wantErr, err)
            }
            if !tc.wantErr && got != tc.want {
                t.Errorf("divide(%v,%v) = %v; want %v", tc.a, tc.b, got, tc.want)
            }
        })
    }
}

// Run a specific sub-test:
// go test -run TestDivide/zero_divisor
```

## The Comma-OK Idiom

Appears in three places in Go — learn to recognize all three:

```go
// 1. Map lookup
age, ok := m["alice"]

// 2. Type assertion (safe — never panics)
n, ok := val.(int)

// 3. Channel receive (ok=false when closed+empty)
v, ok := <-ch
```

## init() — Use Sparingly

```go
// init() runs once per package, before main.
// Multiple init()s allowed in a file/package — run in source order.
// Execution order across packages follows import graph (dependencies first).

// ✓ OK: registering drivers, formats, codecs
func init() {
    sql.Register("pgx", &pgxDriver{})
    image.RegisterFormat("png", "\x89PNG", png.Decode, png.DecodeConfig)
}

// ✗ Avoid: complex logic, I/O, anything that can fail silently
// Errors in init() often cause panics that are hard to diagnose.
```

## Sentinel Errors as Package-Level Variables

```go
// Declare at package level so callers can use errors.Is
var (
    ErrNotFound   = errors.New("not found")
    ErrPermission = errors.New("permission denied")
    ErrConflict   = errors.New("conflict")
)

// Callers compare symbolically:
if errors.Is(err, store.ErrNotFound) {
    http.NotFound(w, r)
    return
}
```

## The `Must` Wrapper for Initialization

```go
// Must panics if err != nil — safe ONLY at program startup
func mustDial(addr string) *grpc.ClientConn {
    conn, err := grpc.Dial(addr, grpc.WithInsecure())
    if err != nil {
        panic(fmt.Sprintf("mustDial %s: %v", addr, err))
    }
    return conn
}

// Standard library uses this pattern:
var re = regexp.MustCompile(`^[a-z]+$`)
var tmpl = template.Must(template.ParseFiles("base.html"))
```

## Embedding for Interface Composition

```go
// Build small interfaces, compose them
type Reader interface { Read([]byte) (int, error) }
type Writer interface { Write([]byte) (int, error) }
type Closer interface { Close() error }

type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}

// Embed concrete types to "inherit" method sets
type LoggingWriter struct {
    io.Writer        // embedded — all Write calls available on LoggingWriter
    log *log.Logger
}

func (lw *LoggingWriter) Write(p []byte) (int, error) {
    lw.log.Printf("writing %d bytes", len(p))
    return lw.Writer.Write(p) // delegate to embedded
}
```

## Struct With Interface Field — Dependency Injection

```go
// Depend on an interface, not a concrete type
type EmailSender interface {
    Send(to, subject, body string) error
}

type Notifier struct {
    email EmailSender // swap in a mock for tests
}

func (n *Notifier) NotifyUser(user string) error {
    return n.email.Send(user, "Hello", "Welcome!")
}

// Production
notifier := &Notifier{email: &SMTPSender{...}}

// Test
type mockEmail struct{ sent []string }
func (m *mockEmail) Send(to, subj, body string) error {
    m.sent = append(m.sent, to); return nil
}
notifier := &Notifier{email: &mockEmail{}}
```
