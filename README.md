# MissingPatterns

<div align="center">
  <img src="https://raw.githubusercontent.com/dantebertuzzi/MissingPatterns.jl/main/logo.png" alt="Logo do MissingPatterns.jl" width="200">
</div>

`MissingPatterns` is a terminal-based toolkit for exploring missing data
patterns in any [Tables.jl](https://github.com/JuliaData/Tables.jl)-compatible
source (`DataFrame`, `CSV.File`, `NamedTuple` of vectors, row tables, ...) —
zero plotting-library dependencies, pure Unicode/ANSI terminal rendering.

[![Stable Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/stable)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/dev)
[![Build Status](https://github.com/dantebertuzzi/MissingPatterns.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/dantebertuzzi/MissingPatterns.jl/actions)
[![Coverage](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl)
[![JuliaHub](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fjuliahub.com%2Fapi%2Fv2%2Fpackages%2FMissingPatterns%2Fversion&query=version&label=version&color=green)](https://juliahub.com/ui/Packages/MissingPatterns/41be38da)

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

| Function | What it shows |
|---|---|
| [`plotmissing`](#plotmissing--missing-value-heatmap) | *Where*/*how much* is missing (heatmap) |
| [`missingpatterns`](#missingpatterns--unique-missingness-patterns) | *Which columns* go missing *together* (à la `mice::md.pattern()`) |
| [`missingsummary`](#missingsummary--per-column-missing-summary) | Per-column counts, % and a distribution sparkline |
| [`missingcooccurrence`](#missingcooccurrence--pairwise-correlation-of-missingness) | Pairwise ϕ/Jaccard correlation of missingness masks |
| [`plotmissingdiff`](#plotmissingdiff--beforeafter-comparison) | Before/after diff (e.g. auditing an imputation step) |
| [`missinghtml`](#missinghtml--html-heatmap-export) | The heatmap as a standalone HTML fragment |

### `plotmissing` — Missing-value heatmap

Shows *where* and *how much* data is missing. Each cell represents the
proportion of missing values in that block.

```julia
plotmissing(tbl)
plotmissing(tbl; layout=:compact)              # half-block compact mode
plotmissing(tbl; layout=:auto, target_lines=28) # fit within N lines
plotmissing(tbl; color=:always)                 # force ANSI/truecolor output
plotmissing(tbl; color=:always, emphasis=:missing, missing_color="#ff6600")
plotmissing(tbl; max_rows=20, max_cols=10, cell_chars=3)
plotmissing(tbl; char_missing='X', char_present='.')
plotmissing(tbl; name_width=6)
plotmissing(tbl; show_row_range=true)           # show original row ranges
```

| Kwarg | Default | Description |
|---|---|---|
| `layout` | `:auto` | `:auto`, `:classic`, or `:compact` (half-block truecolor) |
| `color` | `:auto` | `:auto` (TTY detection), `:always`, or `:never` |
| `emphasis` | `:present` | `:present` or `:missing` — which side of the data carries the ink |
| `missing_color` | `"#f3a9a9"` | Hex color (`"#rrggbb"`) of the ramp |
| `target_lines` | `28` | Max lines for the compact layout |
| `max_rows` | `50` | Display rows before compression (classic layout) |
| `max_cols` | `20` | Display columns before compression |
| `cell_chars` | `5` | Width of each grid cell (max 80) |
| `char_missing` | `'█'` | Character for fully-missing cells |
| `char_present` | `'░'` | Character for fully-present cells |
| `name_width` | `4` | Column-name max chars before truncating (`0` = full name) |
| `color_cells` | `false` | Apply the color ramp to classic-layout glyphs |
| `show_row_range` | `false` | Show row-range (or period) labels on the left |
| `by` | `nothing` | Name of a column — group rows by category or calendar period instead of position |
| `period` | `nothing` | `nothing` (categorical grouping by `by`'s exact value), or `:year`, `:quarter`, `:month`, `:week`, `:day` for a `Date`/`DateTime` `by` column |

#### Layouts

- **`:classic`** — one grid row per line, with a 3-line header and a 6-line summary. Best in a full terminal with room to scroll.
- **`:compact`** — fits the *entire* plot in at most `target_lines` lines, so IDE/Jupyter output cells never truncate it. With color available, each output line encodes **two** grid rows via `▀` (foreground = top row, background = bottom row), doubling vertical resolution.
- **`:auto`** (default) — uses `:classic` when it fits within `target_lines`, `:compact` otherwise.

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

Rows are grouped by the *values* of the `by` column (not by position), so the
vertical axis becomes honest categories or calendar time instead of arbitrary
row ranges. With `period=nothing` (default), groups are the column's exact
values, sorted — works for any sortable column (`String`, `Symbol`, `Int`,
...). With `period` set to a calendar unit, groups are periods of a
`Date`/`DateTime` column (e.g. `2004`, `2013-Q2`). Rows whose `by` value is
`missing` form a trailing `∅` group either way.

### `missingpatterns` — Unique missingness patterns

Shows *which combinations* of columns are missing together — the same
diagnostic produced by R's `mice::md.pattern()`. Patterns are sorted
most-frequent first.

```julia
df = DataFrame(
    A = [1, missing, 3, missing, 5, 6, 7, missing],
    B = [missing, 2, 3, missing, 5, 6, 7, missing],
    C = [1, 2, 3, 4, missing, 6, 7, 8],
)

missingpatterns(df)
```

```
┏━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━┓
┃    A    ┃    B    ┃    C    ┃    n    ┃    %    ┃
┣━━━━━━━━━╋━━━━━━━━━╋━━━━━━━━━╋━━━━━━━━━╋━━━━━━━━━┫
┃  ░░░░░  ┃  ░░░░░  ┃  ░░░░░  ┃    3    ┃  37.5%  ┃
┃  █████  ┃  █████  ┃  ░░░░░  ┃    2    ┃  25.0%  ┃
┃  ░░░░░  ┃  █████  ┃  ░░░░░  ┃    1    ┃  12.5%  ┃
┃  █████  ┃  ░░░░░  ┃  ░░░░░  ┃    1    ┃  12.5%  ┃
┃  ░░░░░  ┃  ░░░░░  ┃  █████  ┃    1    ┃  12.5%  ┃
┗━━━━━━━━━┻━━━━━━━━━┻━━━━━━━━━┻━━━━━━━━━┻━━━━━━━━━┛

 5 unique patterns across 8 rows
```

```julia
missingpatterns(tbl; max_patterns=10, min_pct=5.0)  # hide rare patterns
missingpatterns(tbl; color_cells=true, emphasis=:missing)
missingpatterns(tbl; show_bar=false)                # hide the UpSet-style frequency bar
```

`max_patterns` (default `20`) caps how many rows are displayed; `min_pct`
(default `0.0`) hides patterns matching fewer than that percentage of rows.
`cell_chars`, `char_missing`, `char_present`, `name_width`, `color_cells`,
`missing_color` and `emphasis` behave exactly as in `plotmissing`.

### `missingsummary` — Per-column missing summary

Shows each column's type, missing count, percentage, and a sparkline of
where along the rows the missing values concentrate.

```julia
missingsummary(tbl)
missingsummary(tbl; sortby=:missing)  # sort by missing count, descending (default)
missingsummary(tbl; sortby=:name)     # alphabetical
missingsummary(tbl; sortby=:none)     # original column order
missingsummary(tbl; bins=5)           # group sparkline into 5 bins instead of 20
missingsummary(tbl; color=:always)
```

### `missingcooccurrence` — Pairwise correlation of missingness

Computes the ϕ (phi) coefficient or Jaccard index between every pair of
columns' missingness masks. Positive values indicate columns tend to be
missing *together*; this complements `missingpatterns` with a
correlation-style view of the same question.

```julia
missingcooccurrence(tbl)
missingcooccurrence(tbl; method=:jaccard)  # Jaccard index instead of ϕ (default)
missingcooccurrence(tbl; max_cols=10)      # cap displayed columns (default 20)
missingcooccurrence(tbl; color=:always)
```

### `plotmissingdiff` — Before/after comparison

Compares two versions of a dataset (e.g. before/after an imputation step)
and highlights cells where missing values were resolved (`-`, fewer missing)
or introduced (`+`, more missing).

```julia
before = (a=[missing, 2, missing, 4], b=[1, missing, 3, 4])
after  = (a=[1,       2, 3,       4], b=[1, 2,       missing, 4])

plotmissingdiff(before, after)
plotmissingdiff(before, after; color=:always)
```

### `missinghtml` — HTML heatmap export

Renders the same heatmap and color ramp as `plotmissing` as a standalone,
self-contained HTML fragment (no external CSS/JS) — suitable for reports,
blog posts, or notebook exports. Every cell carries a tooltip with its row
range and exact missing percentage.

```julia
missinghtml(tbl)                                          # returns a String
missinghtml(tbl; title="My Report", emphasis=:missing, missing_color="#ff0000")
missinghtml("/path/to/report.html", tbl)                  # writes to a file, returns the path
```

## Large Datasets

When a table exceeds `max_rows`/`max_cols` (or the `:compact` layout's own
budget), multiple rows/columns are compressed into single cells. The
character gradient shows the proportion of missing values in each block:

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

Every function (except `missinghtml`, which returns/writes a `String`)
accepts an optional leading `io::IO` argument, defaulting to `stdout`:

```julia
# Write to a file
open("missing_report.txt", "w") do f
    plotmissing(f, tbl)
end

# Capture to a string
io = IOBuffer()
plotmissing(io, tbl)
report = String(take!(io))
```

Use `color=:always` when redirecting to a destination that renders ANSI but
isn't a TTY (e.g. a VS Code or Jupyter output cell), and `color=:never` when
writing plain text to a file.

## Tables.jl Compatibility

All functions accept any [Tables.jl](https://github.com/JuliaData/Tables.jl)-compatible
source — DataFrames.jl is not a dependency of the package itself.

```julia
using DataFrames, CSV

# DataFrame
plotmissing(DataFrame(a=[1,missing,3], b=[4,5,missing]))

# NamedTuple of vectors
plotmissing((a=[1,missing,3], b=[4,5,missing]))

# CSV file
plotmissing(CSV.File("data.csv"))
```

## Features

- **Zero plotting dependencies** — pure Unicode/ANSI terminal rendering
- **Tables.jl-native** — works with any compatible source, not just DataFrames
- **Automatic compression** for large datasets, with enhanced sensitivity to subtle patterns
- **Compact half-block layout** with truecolor gradients for IDE/Jupyter output cells
- **Grouping** by category (any sortable column) or by calendar year/quarter/month/week/day
- **Pattern detection** (`missingpatterns`) and **pairwise correlation** (`missingcooccurrence`) of missingness
- **Before/after diffing** (`plotmissingdiff`) for auditing imputation steps
- **HTML export** (`missinghtml`) for reports and notebooks
- **IO-customizable output** — render to `stdout`, a file, or an `IOBuffer`
- **TTY-aware ANSI/truecolor coloring** — colors enabled only where supported
