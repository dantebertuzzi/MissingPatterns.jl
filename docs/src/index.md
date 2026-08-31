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
| `layout` | `:auto` | `:classic`, `:compact` (half-block), or `:auto` |
| `color` | `:auto` | `:always`, `:never`, or `:auto` (TTY detection) |
| `emphasis` | `:present` | `:missing` or `:present` — which cells get color |
| `missing_color` | `"#f3a9a9"` | Hex color for missing cells |
| `target_lines` | `28` | Max lines for compact layout |
| `max_rows` | `50` | Display rows before compression |
| `max_cols` | `20` | Display columns before compression |
| `cell_chars` | `5` | Width of each grid cell |
| `char_missing` | `█` | Character for fully missing cells |
| `char_present` | `░` | Character for fully present cells |
| `name_width` | `4` | Column-name max chars (`0` = full name) |
| `show_row_range` | `false` | Show row-number labels |
| `by` | `nothing` | Name of a column — group rows by category or calendar period instead of position |
| `period` | `nothing` | `nothing` (categorical grouping by `by`'s exact value), or `:year`, `:quarter`, `:month`, `:week`, `:day` for a `Date`/`DateTime` `by` column |

#### Grouping by category or by time

```julia
# categorical grouping (period=nothing, the default): groups by exact value
tbl = (region = ["north", "south", "north", "east"], v = [1, missing, 3, missing])
plotmissing(tbl; by=:region)

# temporal grouping: groups by calendar period of a Date/DateTime column
using Dates
tbl2 = (date = [Date(2023,1,15), Date(2024,6,1), Date(2024,6,2)],
        v    = [1, missing, 3])

plotmissing(tbl2; by=:date, period=:year)
plotmissing(tbl2; by=:date, period=:quarter)
plotmissing(tbl2; by=:date, period=:month)
plotmissing(tbl2; by=:date, period=:week)
plotmissing(tbl2; by=:date, period=:day)
```

Rows whose `by` value is `missing` form a trailing `∅` group in either mode.

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

### `missingrows` — Per-row completeness

The transposed view: not *which* columns are missing, but *how many* values
are missing in each row. The `0` line is the complete-case count — everything
below it is what `dropmissing` would discard.

```julia
missingrows(tbl)
missingrows(tbl; sortby=:rows)                 # most common shape first
missingrows(tbl; bar_width=50)
missingrows(tbl; color=:always)
```

```
 missing/row  rows        %  distribution
 0               3   37.50%  ██████████████████████████████
 1               3   37.50%  ██████████████████████████████
 2               2   25.00%  ████████████████████
 3 complete rows (37.50%) ┊ 5 with ≥1 missing (62.50%) ┊ 3 distinct counts across 3 columns
```

### `missinghtml` — HTML heatmap export

Generates a standalone HTML heatmap suitable for reports and notebooks.

```julia
missinghtml(tbl)
missinghtml(tbl; title="My Report", emphasis=:missing, missing_color="#ff0000")
missinghtml(tbl; by=:region)                   # same grouping as plotmissing
missinghtml("/path/to/report.html", tbl)
```

### `missingreport` — One object, two media

Returns an object that renders itself as the terminal heatmap under
`MIME"text/plain"` and as the HTML heatmap under `MIME"text/html"`. The same
expression shows Unicode in a REPL and a colored, tooltipped grid in Jupyter
or Pluto, with no branching on the caller's side.

```julia
missingreport(tbl)
missingreport(tbl; emphasis=:missing, missing_color="#ff6600")
missingreport(tbl; by=:region)                 # grouped in both media
missingreport(tbl; layout=:compact, title="Cohort A")

show(stdout, MIME"text/html"(), missingreport(tbl))   # force one medium
```

It accepts the keyword arguments of both `plotmissing` and `missinghtml` and
forwards each only to the renderer that takes it, so per-medium defaults (a
200×60 HTML grid vs a 50×20 terminal grid) survive unless overridden. An
unknown keyword is an error immediately, not at display time.

## Getting the numbers out

Every view has a data counterpart returning a plain Tables.jl-compatible row
table (`Vector{<:NamedTuple}`) — no display compression, no
`max_patterns`/`max_cols` cap, nothing printed. They share the same kernels as
the renderers, so a number read here can never disagree with the one drawn on
screen.

| Function | One row per | Key fields |
|---|---|---|
| `missingstats` | column | `column`, `eltype`, `nmissing`, `npresent`, `nrows`, `pct` |
| `missingpatternstats` | unique missingness pattern | `pattern` (a `NamedTuple` of `Bool` keyed by column), `nmissing`, `n`, `pct` |
| `missingpairstats` | unordered pair of columns | `a`, `b`, `phi`, `jaccard`, `n11`, `n1`, `n2`, `nrows` |
| `missingrowstats` | observed missing-count | `nmissing`, `nrows`, `pct` |

```julia
using DataFrames

DataFrame(missingstats(df))                        # straight into a DataFrame
filter(r -> r.pct > 20, missingstats(df))          # columns worse than 20% missing

sort(missingpairstats(df); by = r -> -r.phi)[1:5]  # most co-missing column pairs

ps = missingpatternstats(df)
filter(r -> r.pattern.age && !r.pattern.income, ps)

rs = missingrowstats(df)
only(r.nrows for r in rs if r.nmissing == 0)       # complete-case count
sum(r.nrows for r in rs if r.nmissing > 0)         # rows lost to listwise deletion
```

`missingpairstats` returns **both** ϕ and Jaccard rather than selecting one
with a `method` keyword: both fall out of the same `n11`/`n1`/`n2` counts, so
the schema stays fixed regardless of which you read. Undefined coefficients
are `NaN` — `phi` whenever a column is entirely missing or entirely present,
`jaccard` only when neither column has a single missing value.

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