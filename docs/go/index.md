---
hide:
  - toc
---

# Go — A Field Guide

> *From zero to idiomatic, with all the sharp edges mapped.*

Go is a compiled, statically typed language built for simplicity, concurrency, and reliability at scale. This guide covers the language end-to-end — with a focus on **why** things work the way they do.

## What's covered

<div class="grid cards" markdown>

-   :material-code-braces: **Foundations**

    Variables, types, functions, closures, structs, interfaces, errors, defer, slices and maps.

    [Start here →](basics/index.md)

-   :material-alert-outline: **Gotchas**

    The nil interface trap, loop-variable capture, slice sharing, defer in loops, mutex copies, and more.

    [See gotchas →](advanced/gotchas.md)

-   :material-format-quote-open: **Go Proverbs**

    Rob Pike's design principles, each with a concrete code example and reasoning.

    [Read proverbs →](advanced/proverbs.md)

-   :material-arrow-decision: **Channel Patterns**

    Pipelines, fan-out/fan-in, worker pools, semaphores, done channels, and errgroup.

    [Explore patterns →](concurrency/channel-patterns.md)

-   :material-shape-plus: **Generics**

    Type parameters, constraints, `~` underlying types, and when *not* to use generics.

    [Learn generics →](modern/generics.md)

-   :material-lightning-bolt: **unsafe**

    The six legal `unsafe.Pointer` patterns, the `uintptr` trap, and zero-copy string/byte tricks.

    [Use with care →](modern/unsafe.md)

</div>

## Quick reference

| Concept | TL;DR |
|---------|-------|
| Zero values | Every type has one; design your types to make it useful |
| Errors | Return values, not exceptions; wrap with `%w` for context |
| Interfaces | Implicit, structural; accept interfaces, return structs |
| Goroutines | Cheap (~2 KB), but always give them a stopping condition |
| Channels | Unbuffered = rendezvous; buffered = async queue |
| Generics | Great for data structures and slice/map utils; avoid when interface works |
| `unsafe` | Legal in 6 specific patterns only; breaks with future GC changes |

## Setup

```sh
# Install Go (https://go.dev/dl/)
go version          # go1.22+

# A minimal module
mkdir myapp && cd myapp
go mod init github.com/you/myapp
echo 'package main\nimport "fmt"\nfunc main(){fmt.Println("hello")}' > main.go
go run .
```
