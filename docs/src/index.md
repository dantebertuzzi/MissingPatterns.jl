```@meta
CurrentModule = MissingPatterns
```

# MissingPatterns.jl

Terminal-based toolkit for exploring missing data patterns in any
[Tables.jl](https://github.com/JuliaData/Tables.jl)-compatible source —
zero plotting-library dependencies, pure Unicode/ANSI terminal rendering.

## Installation

```julia
using Pkg
Pkg.add("MissingPatterns")
```

## Quick Start

```julia
using MissingPatterns

# Works with NamedTuples, DataFrames, CSV.File, etc.
tbl = (A = [1, missing, 3, 4],
       B = [missing, 2, 3, 4],
       C = [1, missing, missing, 4])

plotmissing(tbl)
```

## Functions

| Function | What it shows | Page |
|---|---|---|
| `plotmissing` | *Where*/*how much* is missing (heatmap) | [Heatmaps](@ref) |
| `plotmissingdiff` | Before/after diff (e.g. auditing an imputation step) | [Heatmaps](@ref) |
| `missingpatterns` | *Which columns* go missing *together* | [Diagnostics](@ref) |
| `missingsummary` | Per-column counts, % and a distribution sparkline | [Diagnostics](@ref) |
| `missingcooccurrence` | Pairwise ϕ/Jaccard correlation of missingness masks | [Diagnostics](@ref) |
| `missingrows` | *How many* values are missing per row | [Diagnostics](@ref) |
| `missinghtml` | The heatmap as a standalone HTML fragment | [Export and output](@ref) |
| `missingreport` | The heatmap as an object that renders itself per medium | [Export and output](@ref) |

Every display above has a data counterpart that returns a Tables.jl-compatible
row table instead of printing — see [Data API](@ref).

Full docstrings are in the [Public API](@ref) reference.
