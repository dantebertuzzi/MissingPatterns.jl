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
| `period` | `nothing` | `nothing` (categorical grouping by `by`'s exact value), or `:year`, `:quarter`, `:month`, `:week` (ISO-8601), `:day` for a `Date`/`DateTime` `by` column |
| `isna` | `ismissing` | Predicate deciding what counts as an absent value |
| `order` | `:table` | Column order: `:table`, `:missing`, `:name` or `:cluster` |

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

### Ordering the columns

Columns are drawn in table order by default, which is an accident of how the
file was written: columns that go missing together are usually scattered, and
the block structure the plot exists to reveal is the hardest thing to see in
it. `order` fixes that.

```julia
plotmissing(tbl; order=:cluster)   # co-missing columns side by side
plotmissing(tbl; order=:missing)   # emptiest columns first
plotmissing(tbl; order=:name)      # alphabetical
```

`:cluster` seriates the ϕ matrix of the missingness masks: it starts at the
column with the most missing values and repeatedly appends the unplaced column
most associated with the last one placed. Columns with no missing values carry
no pattern and are appended at the end, so a complete column never splits a
block in half. It costs one extra pass over the data to build the pattern
table.

Reordering is purely a display concern — every count, percentage and total is
identical whatever the order. When columns are compressed, a reordered group is
labeled by its endpoint names (`age-income`) rather than by positional indices
(`3-7`), which would otherwise refer to display slots instead of to the table.

### Sentinel values with `isna`

Real microdata rarely uses `missing`. DATASUS, the TSE and most public
statistical files code absence as a sentinel: `9`/`99` for "ignored", `""` for
a blank field, sometimes `-1`. `isna` lets those count as holes without
rewriting the table:

```julia
tbl = (idade = [34, 9, 51, 9], sexo = ["M", "", "F", "M"])

plotmissing(tbl)                                             # nothing is missing
plotmissing(tbl; isna = x -> ismissing(x) || x == 9 || x == "")
```

That form applies one predicate to every column, which is rarely what you
want: a sentinel belongs to a *variable*, not to a table. `9` means "ignored"
in a coded field but is a perfectly good age, and the blanket predicate above
punches a hole in `idade` for every 9-year-old. Pass a `NamedTuple` (or a
`Dict`) of per-column predicates instead, with `ismissing` assumed for any
column left out:

```julia
plotmissing(tbl; isna = (idade = x -> ismissing(x) || x == 9,
                         sexo  = x -> ismissing(x) || x == ""))
```

Naming a column the table does not have is an error rather than a silently
ignored entry, so a typo surfaces instead of quietly showing a complete table.

In either form, test `ismissing` first and let `||` short-circuit:
`missing == 9` is `missing`, not `false`, and a bare `x == 9` would throw in a
boolean context.

The predicate reaches every count the package makes — the heatmap, the
diagnostics, the data API and the `by` column, where a sentinel forms the `∅`
group just as `missing` does. It is available on every entry point, including
[`missingsummary`](@ref), [`missingpatterns`](@ref), [`missingdrop`](@ref) and
[`missinghtml`](@ref).

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
