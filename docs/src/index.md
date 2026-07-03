```@meta
CurrentModule = MissingPatterns
```

# MissingPatterns.jl

A terminal-based text heatmap for visualizing missing data patterns in **DataFrames** —
zero plotting-library dependencies, pure Unicode/ANSI terminal rendering.

## Installation

```julia
using Pkg
Pkg.add("MissingPatterns")
```

## Quick Start

```julia
using DataFrames
using MissingPatterns

df = DataFrame(
    A = [1, missing, 3, 4],
    B = [missing, 2, 3, 4],
    C = [1, missing, missing, 4],
)

plotmissing(df)
```

## Large Datasets

When a DataFrame exceeds `max_rows` (default 50) or `max_cols` (default 20),
multiple rows/columns are grouped into a single cell. The character gradient
shows the proportion of missing values in each block:

| Proportion | Char | Color (opt-in) |
|---|---|---|
| 0% (present) | `░` | — |
| 1–5% | `·` | green |
| 5–15% | `░` | yellow |
| 15–30% | `▒` | orange |
| 30–50% | `▓` | red-orange |
| 50–75% | `█` | red |
| 75–100% | `█` | bright red |

```julia
# 20k rows × 10 cols — auto-compressed to 50 display rows
using Random
Random.seed!(123)

nrows, ncols = 20_000, 10
data = [rand() < 0.2 ? missing : rand(1:100) for _ in 1:nrows, _ in 1:ncols]
df_large = DataFrame(data, Symbol.(["Col_$i" for i in 1:ncols]))

plotmissing(df_large)
```

## Output Customization

### Redirecting output

```julia
# Write to a file
open("missing_report.txt", "w") do f
    plotmissing(f, df)
end

# Capture to string
io = IOBuffer()
plotmissing(io, df)
report = String(take!(io))
```

### Cell characters

```julia
plotmissing(df; char_missing='X', char_present='.')
```

### Column-name truncation

```julia
plotmissing(df; name_width=6)   # show up to 6 chars before truncation
plotmissing(df; name_width=0)   # show full names (bounded by cell width)
```

### ANSI color gradient

```julia
plotmissing(df; color_cells=true)  # green→yellow→red per missing proportion
```

### Custom display limits

```julia
plotmissing(df; max_rows=20, max_cols=10, cell_chars=3)
```

## API Reference

```@autodocs
Modules = [MissingPatterns]
```
