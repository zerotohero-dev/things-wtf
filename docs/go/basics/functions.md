# Functions

Functions are **first-class values** in Go — assigned to variables, passed as arguments, returned from other functions.

## Basics

```go
// Basic function
func add(a, b int) int { return a + b }

// Multiple return values — idiomatic for (result, error)
func divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, fmt.Errorf("division by zero")
    }
    return a / b, nil
}

// Variadic — receives remaining args as a slice
func sum(nums ...int) int {
    total := 0
    for _, n := range nums {
        total += n
    }
    return total
}

sum(1, 2, 3)         // normal call
nums := []int{1,2,3}
sum(nums...)          // spread a slice with ...
```

## Named Return Values

Named returns document what's being returned and enable "naked" returns.
Use them **for documentation clarity**, not as a shortcut for naked returns.

```go
func stats(nums []float64) (min, max, mean float64) {
    if len(nums) == 0 {
        return // naked return: min=0, max=0, mean=0
    }
    min, max = nums[0], nums[0]
    var sum float64
    for _, n := range nums {
        if n < min { min = n }
        if n > max { max = n }
        sum += n
    }
    mean = sum / float64(len(nums))
    return // returns current values of min, max, mean
}
```

## Named Returns + Defer: a Subtle Trap

!!! warning "Deferred functions can modify named returns"
    This is sometimes used intentionally (annotating errors), but easy to be surprised by.

=== "Surprising (modify)"
    ```go
    // defer modifies the named return — returns x*2, not x
    func double(x int) (result int) {
        defer func() {
            result *= 2 // modifies the named return!
        }()
        result = x
        return // returns x*2
    }
    ```

=== "Intentional (annotate error)"
    ```go
    // Classic use: annotate Close() errors without losing original
    func writeFile(path string) (err error) {
        f, err := os.Create(path)
        if err != nil { return }
        defer func() {
            if cerr := f.Close(); cerr != nil && err == nil {
                err = cerr // only overwrite if no prior error
            }
        }()
        _, err = f.WriteString("data")
        return
    }
    ```

## Functions as Values

```go
// Assign to a variable
double := func(x int) int { return x * 2 }
fmt.Println(double(5)) // 10

// Pass as argument
func apply(nums []int, fn func(int) int) []int {
    result := make([]int, len(nums))
    for i, n := range nums {
        result[i] = fn(n)
    }
    return result
}
apply([]int{1,2,3}, double) // [2 4 6]

// Return a function
func multiplier(factor int) func(int) int {
    return func(x int) int { return x * factor }
}
triple := multiplier(3)
fmt.Println(triple(4)) // 12
```
