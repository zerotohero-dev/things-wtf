# Theme Variants

Zensical ships with two visual variants of its built-in theme.

## modern (default)

A fresh, contemporary design. This is what you get out of the box.

```toml title="zensical.toml"
[project.theme]
name    = "zensical"
variant = "modern"   # (1)!
```

1. `modern` is the default — you can omit this line entirely.

## classic

An exact visual match for **Material for MkDocs**. Useful when migrating an existing project and wanting to preserve its look while adopting Zensical's new features and config format.

```toml title="zensical.toml"
[project.theme]
name    = "zensical"
variant = "classic"
```

!!! tip "HTML structure is identical in both variants"
    Both `modern` and `classic` share the same underlying HTML structure. Any CSS or JavaScript customization you write works on either. If your customizations behave unexpectedly, switching to `classic` is a reliable fallback.

## Choosing a Variant

| | modern | classic |
|--|--------|---------|
| Default | ✓ | |
| Material for MkDocs look | | ✓ |
| Same HTML structure | ✓ | ✓ |
| CSS/JS customization compatible | ✓ | ✓ |
| Best for new projects | ✓ | |
| Best for MkDocs migrations | | ✓ |
