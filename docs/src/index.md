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

### `plotmissing` — Missing-value heatmap

Shows *where* and *how much* data is missing. Each cell represents
the proportion of missing values in that block.

```julia
plotmissing(tbl)
plotmissing(tbl; layout=:compact)             # half-block compact mode
plotmissing(tbl; layout=:auto, target_lines=28)
plotmissing(tbl; color=:always)                # ANSI/truecolor output
plotmissing(tbl; color=:always, emphasis=:present, missing_color="#ff6600")
plotmissing(tbl; max_rows=20, max_cols=10, cell_chars=3)
plotmissing(tbl; char_missing='X', char_present='.')
plotmissing(tbl; name_width=6)
```

| Kwarg | Default | Description |
|---|---|---|
| `layout` | `:classic` | `:classic`, `:compact` (half-block), or `:auto` |
| `color` | `:auto` | `:always`, `:never`, or `:auto` (TTY detection) |
| `emphasis` | `:missing` | `:missing` or `:present` — which cells get color |
| `missing_color` | `"#f3a9a9"` | Hex color for missing cells |
| `target_lines` | `28` | Max lines for compact layout |
| `max_rows` | `50` | Display rows before compression |
| `max_cols` | `20` | Display columns before compression |
| `cell_chars` | `5` | Width of each grid cell |
| `char_missing` | `█` | Character for fully missing cells |
| `char_present` | `░` | Character for fully present cells |
| `name_width` | `4` | Column-name max chars (`0` = full name) |
| `show_row_range` | `false` | Show row-number labels |

#### Temporal grouping

```julia
using Dates
tbl = (date = [Date(2023,1,15), Date(2024,6,1), Date(2024,6,2)],
       v    = [1, missing, 3])

plotmissing(tbl; by=:date, period=:year)
plotmissing(tbl; by=:date, period=:quarter)
plotmissing(tbl; by=:date, period=:month)
plotmissing(tbl; by=:date, period=:week)
plotmissing(tbl; by=:date, period=:day)
```

### `missingpatterns` — Unique missingness patterns

Shows *which combinations* of columns are missing together —
the same diagnostic as R's `mice::md.pattern()`.
Patterns are sorted most-frequent first.

```julia
missingpatterns(tbl)
missingpatterns(tbl; max_patterns=10, min_pct=5.0)
missingpatterns(tbl; color_cells=true, emphasis=:missing)
missingpatterns(tbl; show_bar=false)           # hide frequency bar
```

### `missingsummary` — Per-column missing summary

Shows each column's type, missing count, percentage, and a
distribution sparkline.

```julia
missingsummary(tbl)
missingsummary(tbl; sortby=:missing)           # sort by missing count (default)
missingsummary(tbl; sortby=:name)
missingsummary(tbl; sortby=:none)
missingsummary(tbl; bins=5)                    # group by bins of N rows
missingsummary(tbl; color=:always)
```

### `missingcooccurrence` — Pairwise correlation of missingness

Computes ϕ (phi) coefficient or Jaccard index between every pair of columns
based on their missingness masks. Positive values indicate columns tend to be
missing *together*.

```julia
missingcooccurrence(tbl)
missingcooccurrence(tbl; method=:jaccard)       # Jaccard instead of ϕ
missingcooccurrence(tbl; max_cols=10)            # cap displayed columns
missingcooccurrence(tbl; color=:always)
```

### `plotmissingdiff` — Before/after comparison

Compares two versions of a dataset and highlights cells where missing
values were resolved (+) or introduced (−).

```julia
before = (a=[missing, 2, missing, 4], b=[1, missing, 3, 4])
after  = (a=[1,       2, 3,       4], b=[1, 2,       missing, 4])

plotmissingdiff(before, after)
plotmissingdiff(before, after; color=:always)
```

### `missinghtml` — HTML heatmap export

Generates a standalone HTML heatmap suitable for reports and notebooks.

```julia
missinghtml(tbl)
missinghtml(tbl; title="My Report", emphasis=:missing, missing_color="#ff0000")
missinghtml("/path/to/report.html", tbl)
```

## Large Datasets

When a table exceeds `max_rows` (default 50) or `max_cols` (default 20),
multiple rows/columns are compressed into single cells. The character
gradient shows the proportion of missing values:

| Proportion | Compressed glyph |
|---|---|
| 0% | `░` |
| 1–5% | `·` |
| 5–15% | `░` |
| 15–30% | `▒` |
| 30–50% | `▓` |
| 50%+ | `█` |

```julia
# 20k rows × 10 cols — auto-compressed to display bounds
using Random
Random.seed!(123)

nrows, ncols = 20_000, 10
data = [rand() < 0.2 ? missing : rand(1:100) for _ in 1:nrows, _ in 1:ncols]
tbl = NamedTuple{Tuple(Symbol("Col_$i") for i in 1:ncols)}(Tuple(view(data, :, j) for j in 1:ncols))

plotmissing(tbl; layout=:compact)
```

## Output Redirection

```julia
# Write to file
open("missing_report.txt", "w") do f
    plotmissing(f, tbl)
end

# Capture to string
io = IOBuffer()
plotmissing(io, tbl)
report = String(take!(io))
```

## Tables.jl Compatibility

All functions accept any [Tables.jl](https://github.com/JuliaData/Tables.jl)-compatible source:
DataFrames, NamedTuples of vectors, CSV.File, row tables, etc.

```julia
using DataFrames, CSV

# DataFrame
plotmissing(DataFrame(a=[1,missing,3], b=[4,5,missing]))

# NamedTuple
plotmissing((a=[1,missing,3], b=[4,5,missing]))

# CSV file
plotmissing(CSV.File("data.csv"))
```

## API Reference

```@autodocs
Modules = [MissingPatterns]
```