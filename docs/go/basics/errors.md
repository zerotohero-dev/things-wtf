# Error Handling

Go treats errors as **values**, not exceptions. Functions return an `error` as their last return value. The caller checks and handles it explicitly.

!!! quote "Go Proverb"
    *"Errors are values."*

    Because errors are just values, you can program with them: store them, wrap them,
    inspect them, count them, pass them through channels.

## Creating Errors

```go
// Simple sentinel error
var ErrNotFound = errors.New("not found")

// Formatted error (no wrapping)
err := fmt.Errorf("user %d not found", id)

// Wrapping — preserves the original for later inspection
err = fmt.Errorf("loadUser: %w", originalErr)  // %w wraps

// Custom error type — carries structured information
type ValidationError struct {
    Field   string
    Message string
}
func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on %s: %s", e.Field, e.Message)
}
```

## Wrapping & Inspecting (Go 1.13+)

```go
// errors.Is — checks identity through the entire error chain
if errors.Is(err, os.ErrNotExist) {
    // file not found, regardless of how many wrapping layers
}

// errors.As — unwraps to a concrete type
var ve *ValidationError
if errors.As(err, &ve) {
    fmt.Println("failed field:", ve.Field)
}

// Unwrap manually
err1 := fmt.Errorf("outer: %w", ErrNotFound)
fmt.Println(errors.Unwrap(err1)) // "not found"
```

## The Handle-or-Return Discipline

!!! tip "One rule: log OR return, never both"
    **Handle** an error when you can recover or present it meaningfully.
    **Return** it (wrapped with context) when the caller should decide.
    Logging *and* returning causes duplicate log lines. Let the top-level handler log once.

=== "✗ Log and return"
    ```go
    func readConfig(path string) (*Config, error) {
        data, err := os.ReadFile(path)
        if err != nil {
            log.Printf("read config error: %v", err) // BAD: also returns
            return nil, err
        }
        ...
    }
    ```

=== "✓ Wrap and return"
    ```go
    func readConfig(path string) (*Config, error) {
        data, err := os.ReadFile(path)
        if err != nil {
            return nil, fmt.Errorf("readConfig: %w", err) // add context
        }
        ...
    }

    // Top-level handler logs once
    cfg, err := readConfig("config.json")
    if err != nil {
        log.Fatalf("startup: %v", err)
    }
    ```

## Sentinel Errors

```go
// Declare at package level for comparison with errors.Is
var (
    ErrNotFound   = errors.New("not found")
    ErrPermission = errors.New("permission denied")
    ErrTimeout    = errors.New("timeout")
)

func Find(id int) (*User, error) {
    if id <= 0 {
        return nil, ErrNotFound
    }
    ...
}

// Caller:
u, err := Find(id)
if errors.Is(err, ErrNotFound) {
    http.Error(w, "Not Found", 404)
    return
}
```

## Error Conventions

| Practice | Why |
|----------|-----|
| Return `error` as the last value | Convention; tools and linters expect it |
| Use lowercase error messages | They're often wrapped: `fmt.Errorf("prefix: %w", err)` |
| Don't end error strings with punctuation | Same reason — they get concatenated |
| Always check errors | `go vet` warns; ignoring errors is a bug |
| Use `%w` when wrapping | Enables `errors.Is` / `errors.As` traversal |
