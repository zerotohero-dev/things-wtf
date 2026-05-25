# Structs & Methods

Go uses structs for data aggregation. There is **no class hierarchy** — composition via embedding replaces inheritance.

## Defining Structs & Methods

```go
type Point struct {
    X, Y float64
}

// Value receiver — reads only, does not mutate
func (p Point) Distance(q Point) float64 {
    dx, dy := p.X-q.X, p.Y-q.Y
    return math.Sqrt(dx*dx + dy*dy)
}

// Pointer receiver — mutates the struct
func (p *Point) Scale(factor float64) {
    p.X *= factor
    p.Y *= factor
}

p := Point{1, 2}
p.Scale(3)            // Go auto-dereferences: (&p).Scale(3)
fmt.Println(p)        // {3 6}

// Struct literals
origin := Point{X: 0, Y: 0}  // named fields — preferred for exported types
other  := Point{0, 0}         // positional — fragile if fields change
```

## Embedding — Composition over Inheritance

```go
type Animal struct {
    Name string
}

func (a Animal) Speak() string { return a.Name + " speaks" }

type Dog struct {
    Animal        // embedded — Dog "inherits" Animal's fields and methods
    Breed string
}

d := Dog{Animal: Animal{Name: "Rex"}, Breed: "Lab"}
fmt.Println(d.Speak()) // "Rex speaks" — promoted method
fmt.Println(d.Name)    // "Rex" — promoted field

// Dog can override Animal's method
func (d Dog) Speak() string { return d.Name + " barks" }
// d.Speak()         → "Rex barks"
// d.Animal.Speak()  → "Rex speaks" (original still accessible)
```

!!! info "Embedding is delegation, not inheritance"
    A `Dog` is **not** an `Animal` in the type system — you can't pass a `Dog` where an `Animal`
    is expected. Embedding promotes fields and methods; it doesn't establish a subtype relationship.
    For polymorphism, use interfaces.

## Struct Tags

```go
type User struct {
    Name  string `json:"name" db:"user_name"`
    Email string `json:"email,omitempty"` // omit if empty
    Age   int    `json:"-"`              // always exclude from JSON
}

// Tags are string literals read at runtime via reflect.
// Used by encoding/json, database drivers, validators, etc.
// Format is: `key:"value" key2:"value2"`
```

## Receiver Cheat Sheet

| Scenario | Receiver type |
|----------|--------------|
| Method mutates the receiver | Pointer `*T` |
| Struct is large (avoid copy) | Pointer `*T` |
| Receiver holds a mutex | Pointer `*T` |
| Method only reads, struct is small | Value `T` |
| Type is a map, slice, chan, func | Value `T` (already a reference) |
| Consistency — other methods use pointer | Pointer `*T` |

!!! tip "Be consistent"
    Don't mix pointer and value receivers on the same type — it's confusing for callers
    and prevents the type from satisfying some interface constraints.
