# Slices & Maps

## Slices

A slice is a **descriptor** (pointer, length, capacity) over an underlying array. Understanding this model is essential to avoid subtle bugs.

```go
// Slice literal — creates backing array + slice descriptor
s := []int{1, 2, 3, 4, 5}
fmt.Println(len(s), cap(s)) // 5, 5

// make: specify length and optional capacity
s2 := make([]int, 3)       // len=3, cap=3, all zeros
s3 := make([]int, 0, 10)   // len=0, cap=10 — pre-allocated buffer

// append: extends if cap permits; otherwise allocates a new backing array
s = append(s, 6, 7)

// copy: always independent — no shared backing array
dst := make([]int, len(src))
copy(dst, src)
```

### Slice Sharing

!!! danger "Slices share the underlying array"
    Taking a sub-slice does **not** copy data. Modifying the sub-slice modifies the original.
    Appending to the sub-slice may silently overwrite the original if there's remaining capacity.

```go
a := []int{0, 1, 2, 3, 4}
b := a[1:3]        // b = [1 2]; shares a's array; cap(b) = 4

b[0] = 99          // modifies a too! a is now [0 99 2 3 4]

b = append(b, 100) // len < cap, no realloc — overwrites a[3]!
                   // a is now [0 99 2 100 4]
```

=== "✓ 3-index slice — cap the capacity"
    ```go
    // a[low : high : max] — cap = max-low
    b := a[1:3:3]      // len=2, cap=2 — append forces new allocation
    b = append(b, 100) // new backing array; a is untouched
    ```

=== "✓ Copy — explicit independence"
    ```go
    b := make([]int, 2)
    copy(b, a[1:3])    // completely independent
    ```

### Slice Tricks

```go
// Delete element at index i (order preserved)
s = append(s[:i], s[i+1:]...)

// Delete element at index i (order not preserved, faster)
s[i] = s[len(s)-1]
s = s[:len(s)-1]

// Filter in place (no allocation)
n := 0
for _, v := range s {
    if keep(v) {
        s[n] = v
        n++
    }
}
s = s[:n]
```

## Maps

```go
// Map literal
m := map[string]int{
    "alice": 30,
    "bob":   25,
}

// make
m2 := make(map[string]int)
m2["charlie"] = 40

// Delete
delete(m, "bob")
```

### The Comma-OK Idiom

!!! warning "Reads return zero for missing keys"
    For `map[string]int`, you can't tell if a key is absent or has value `0` without the comma-ok idiom.

```go
age, ok := m["alice"]  // age=30, ok=true
age, ok  = m["dave"]   // age=0 (zero value!), ok=false

// Always use comma-ok when zero vs missing matters:
if count, ok := m[key]; ok {
    fmt.Println("found:", count)
} else {
    fmt.Println("not found")
}
```

### Map Iteration

```go
// Iteration order is RANDOMIZED by design — never rely on it
for k, v := range m {
    fmt.Printf("%s: %d\n", k, v)
}

// If you need sorted keys:
keys := make([]string, 0, len(m))
for k := range m { keys = append(keys, k) }
sort.Strings(keys)
for _, k := range keys { fmt.Println(k, m[k]) }
```

!!! danger "Maps are not safe for concurrent access"
    Writing to a map from multiple goroutines is a **data race** and will crash the program.
    Use `sync.RWMutex` or `sync.Map` when sharing maps across goroutines.
