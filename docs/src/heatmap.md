# Heatmaps

## `plotmissing` — Missing-value heatmap

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

### Grouping by category or by time

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

## `plotmissingdiff` — Before/after comparison

Compares two versions of a dataset and highlights cells where missing
values were resolved (+) or introduced (−).

```julia
before = (a=[missing, 2, missing, 4], b=[1, missing, 3, 4])
after  = (a=[1,       2, 3,       4], b=[1, 2,       missing, 4])

plotmissingdiff(before, after)
plotmissingdiff(before, after; color=:always)
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
