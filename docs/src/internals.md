```@meta
CurrentModule = MissingPatterns
```

# Internals

Non-exported helpers, documented because the package's architecture is split
into a calculation stage (table → stats structs, no IO), a rendering stage
(stats → IO, no data-shape decisions) and a data stage (table → Tables.jl row
tables). **These are not public API** — they can change in any release without
a breaking version bump.

```@autodocs
Modules = [MissingPatterns]
Public = false
```
