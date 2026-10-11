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
[![Build Status](https://github.com/dantebertuzzi/MissingPatterns.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/dantebertuzzi/MissingPatterns.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://coveralls.io/repos/github/dantebertuzzi/MissingPatterns.jl/badge.svg?branch=main)](https://coveralls.io/github/dantebertuzzi/MissingPatterns.jl?branch=main)
[![JuliaHub](https://docs.juliahub.com/General/MissingPatterns/stable/version.svg)](https://juliahub.com/ui/Packages/General/MissingPatterns)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22217099.svg)](https://doi.org/10.5281/zenodo.22217099)
[![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/getting-started.ipynb)

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

## Notebooks

Nothing to install to try it: Google Colab runs Julia natively, and every notebook below opens
there from the badge. Pick the Julia runtime under *Runtime ▸ Change runtime type* and run the
cells. All are committed with the outputs of a real run, so they also read on GitHub without
being executed.

| Notebook | What it does |
|---|---|
| [`getting-started.ipynb`](notebooks/getting-started.ipynb) [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/getting-started.ipynb) | The tour, on a table whose missingness was put there on purpose — and then found with the package rather than by knowing where it was. Every entry point, the `isna` sentinel form, grouping by category and by calendar period, the data API, and an imputation audited with `plotmissingdiff`. |
| [`obis-missingness.ipynb`](notebooks/obis-missingness.ipynb) [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/obis-missingness.ipynb) | The same diagnostics on real data: marine biodiversity records pulled live from [OBIS](https://obis.org) with [OBISClient.jl](https://github.com/dantebertuzzi/OBISClient.jl). Two depth fields that turn out to be one, a provenance split hiding in a negative ϕ, not a single complete record in three thousand — and a check of the sample against OBIS's own counts for the whole query. |
| [`whats-new-0.7.ipynb`](notebooks/whats-new-0.7.ipynb) [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/whats-new-0.7.ipynb) | What 0.7 adds, on the getting-started table: Little's MCAR test — including the mechanism it cannot see — then `missingsentinels` finding the coded absences and `missingpredictors` finding that mechanism, pattern tables ordered by structure, grouped plots without the grouping column, row labels in HTML, and two releases of a table compared by key with `plotmissingdiff(...; on)`. |

## Functions

| Function | What it shows |
|---|---|
| [`plotmissing`](#plotmissing--missing-value-heatmap) | *Where*/*how much* is missing (heatmap) |
| [`missingpatterns`](#missingpatterns--unique-missingness-patterns) | *Which columns* go missing *together* (à la `mice::md.pattern()`) |
| [`missingsummary`](#missingsummary--per-column-missing-summary) | Per-column counts, % and a distribution sparkline |
| [`missingcooccurrence`](#missingcooccurrence--pairwise-correlation-of-missingness) | Pairwise ϕ/Jaccard correlation of missingness masks |
| [`plotmissingdiff`](#plotmissingdiff--beforeafter-comparison) | Before/after diff (e.g. auditing an imputation step) |
| [`missingrows`](#missingrows--per-row-completeness) | *How many* values are missing per row (what listwise deletion costs) |
| [`missingdrop`](#missingdrop--what-dropping-a-column-buys) | Which column to drop to buy back complete rows |
| [`missingmcar`](#missingmcar--littles-mcar-test) | Little's test of missing completely at random |
| [`missingsentinels`](#missingsentinels--absence-that-does-not-say-missing) | Values that probably encode absence (`9`, `""`, `"NA"`…), ready for `isna` |
| [`missingpredictors`](#missingpredictors--what-the-missingness-depends-on) | What a column's missingness depends on (the MAR diagnostic) |
| [`missinghtml`](#missinghtml--html-heatmap-export) | The heatmap as a standalone HTML fragment |
| [`missingreport`](#missingreport--one-object-two-media) | The heatmap as an object that renders itself in terminal *or* HTML |

Every display above has a data counterpart that returns a
[Tables.jl](https://github.com/JuliaData/Tables.jl)-compatible row table
instead of printing — see [Getting the numbers out](#getting-the-numbers-out).

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
| `period` | `nothing` | `nothing` (categorical grouping by `by`'s exact value), or `:year`, `:quarter`, `:month`, `:week` (ISO-8601), `:day` for a `Date`/`DateTime` `by` column |
| `isna` | `ismissing` | Predicate deciding what counts as an absent value |
| `order` | `:table` | Column order: `:table`, `:missing`, `:name` or `:cluster` |
| `exclude_by` | `true` | Leave the `by` column itself out of the grid |

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
`missing` form a trailing `∅` group either way. The `by` column itself is
left out of the grid — it would only restate the grouping, present in every
group and missing in `∅` — and the summary's totals cover the columns drawn;
pass `exclude_by=false` to keep it.

#### Ordering the columns

Columns are drawn in table order by default — an accident of how the file was
written, which usually scatters the columns that go missing together and hides
the very structure the plot exists to show.

```julia
plotmissing(tbl; order=:cluster)   # co-missing columns side by side
plotmissing(tbl; order=:missing)   # emptiest columns first
plotmissing(tbl; order=:name)      # alphabetical
```

`:cluster` seriates the ϕ matrix of the missingness masks, starting at the
column with the most missing values and repeatedly appending the unplaced
column most associated with the last one placed. Columns with no missing values
carry no pattern and go to the end, so a complete column never splits a block
in half.

Reordering is display-only: every count, percentage and total is identical
whatever the order.

#### Sentinel values with `isna`

Real microdata rarely uses `missing`. DATASUS, the TSE and most public
statistical files code absence as a sentinel: `9`/`99` for "ignored", `""` for
a blank field. `isna` counts those as holes without rewriting the table:

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

The predicate is available on **every** entry point — heatmap, diagnostics,
data API, HTML export — and applies to the `by` column too, where a sentinel
forms the `∅` group just as `missing` does.

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
missingpatterns(tbl; order=:cluster)                # co-missing columns side by side
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

When the two releases do not line up row for row — re-sorted, filtered or
appended to — pair them by a key column instead of by position:

```julia
plotmissingdiff(release_2023, release_2024; on=:id)
```

Only keys present on both sides are compared; the summary says how many rows
each side had that the other did not.

### `missingrows` — Per-row completeness

The transposed view: not *which* columns are missing, but *how many* values
are missing in each row. The `0` line is the complete-case count — everything
below it is what `dropmissing` would throw away.

```julia
missingrows(tbl)
missingrows(tbl; sortby=:rows)     # most common shape first (default: :nmissing)
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

### `missingdrop` — What dropping a column buys

`missingrows` prices listwise deletion for the table as it stands.
`missingdrop` prices the alternative — trading a variable for rows — and names
the variable worth trading. It walks the greedy path, at each step removing the
column that turns the most rows complete.

```julia
missingdrop(tbl)
missingdrop(tbl; bar_width=50)
missingdrop(tbl; color=:always)
```

```
 drop    cols  complete        %  distribution
 —          5       626   62.60%  ███████████████████
 lab        4       940   94.00%  ████████████████████████████  ◀ most complete-case cells
 income     3       980   98.00%  █████████████████████████████
 age        2      1000  100.00%  ██████████████████████████████
 626 of 1000 rows complete as given (62.60%) ┊ dropping 1 column leaves 940 complete across 4 columns (94.00%)
```

Dropping `lab` alone takes complete-case analysis from 626 rows to 940, at the
price of one variable. The flag marks the step maximizing `complete × columns
left` — the size of the surviving complete-case block. Whether that trade is
worth making is a modeling judgment; the package only prices it.

### `missingmcar` — Little's MCAR test

Every view above *suggests* a mechanism. `missingmcar` tests the one most
analyses assume without saying so: that whether a value is missing has nothing
to do with the data — *missing completely at random*. Little's (1988) test
compares each pattern's observed means with the maximum-likelihood means of the
whole table (estimated by EM under a multivariate normal model); under MCAR the
weighted distance is χ²-distributed.

```julia
r = missingmcar(tbl)                              # every real-valued column
r = missingmcar(tbl; columns=[:age, :weight])     # a subset
r = missingmcar(tbl; isna=(income = x -> ismissing(x) || x == 99,))
```

On a table where older respondents refuse to state their income:

```
julia> missingmcar(tbl)
(statistic = 124.6, df = 5, pvalue = 3.3e-25, npatterns = 4, ...)

julia> missingmcar(tbl; columns=[:age, :weight])  # weight is missing at random
(statistic = 0.3, df = 1, pvalue = 0.585, ...)
```

A small p-value is evidence *against* MCAR, so complete-case analysis is likely
biased. A large one fails to reject it; it does not prove it, and it cannot tell
MAR from MNAR. The test is defined for continuous columns: by default every
column with a real element type is used (`Bool` excluded), and rows with nothing
observed are left out. The result also carries the EM estimates (`mu`, `sigma`)
and whether EM converged.

### `missingsentinels` — Absence that does not say `missing`

Administrative microdata code absence as values — `9` for "ignored", `999` for
"not stated", an empty string, `"NA"`, `"ignorado"`. `isna` counts them as
missing, but someone has to find them first. `missingsentinels` proposes
candidates, each with the evidence for it:

```julia
found = missingsentinels(tbl)
DataFrame(found)
```

```
 Row │ column     value  n      pct      reason
─────┼───────────────────────────────────────────────────────────────────
   1 │ schooling  99       206     20.6  above every other value (max 3)
```

Text is proposed when it is blank or reads as absent. A numeric code (`9`,
`99`, …, `-1`, `-9`, …) is only proposed when the data back it: it lies beyond
every other value of its column, past a gap, or it is at least five times as
frequent as the values around it — so `9` in a 0–9 scale, or `99` in an age
column that reaches 105, is left alone. Codes stored as text (`"9"` among
`"1"`…`"5"`) are judged as numbers. The rules are on the
*Methods* page of the documentation.

These are **candidates for review**. Keep the ones that are codes and turn
them into the per-column `isna` every other function takes:

```julia
isna = sentinelisna(found)                                  # all of them
isna = sentinelisna(filter(r -> r.column != :age, found))   # all but one column
missingsummary(tbl; isna)
```

### `missingpredictors` — What the missingness depends on

[`missingmcar`](#missingmcar--littles-mcar-test) says *whether* the missingness is related to the data;
`missingpredictors` says *to what*. For one column, every other column is
compared between the rows where it is missing and the rows where it is
present — Welch's t-test for numbers and dates, a χ² test of independence for
everything else — and sorted by p-value. A column that differs predicts the
missingness: that is the working diagnostic for MAR, and the list of variables
an imputation model for the column must include.

```julia
missingpredictors(tbl, :income; isna)
```

```
 column     test     pvalue    effect  detail
 region     chisq    2.18e-08    0.20  south: 42.1% of rows where missing vs 20.9% where present
 age        welch_t  1.82e-05    0.35  mean 60 where missing vs 52.47 where present
 date       welch_t  0.242       0.09  mean 2022-02-18 where missing vs 2021-12-21 where present
 schooling  welch_t  0.7         0.03  mean 1.509 where missing vs 1.472 where present
 lab        welch_t  0.756      -0.03  mean 3.429 where missing vs 3.456 where present
 weight     welch_t  0.87        0.02  mean 60.32 where missing vs 60.15 where present
```

Income is refused more in the south and by older respondents — which is how
this table was built. For numeric columns `effect` is the standardized mean
difference (0.2 small, 0.5 medium, 0.8 large by Cohen's convention); for the
others it is Cramér's V. Dates are compared as dates, which catches what
`missingmcar` cannot: the same call on `:lab` puts `date` first, with
`p = 1.7e-19` and a mean a year earlier where `lab` is missing.

One test is run per column, so with many columns a few unrelated ones will come
out significant by chance; read the effect sizes alongside the p-values.

### `missinghtml` — HTML heatmap export

Renders the same heatmap and color ramp as `plotmissing` as a standalone,
self-contained HTML fragment (no external CSS/JS) — suitable for reports,
blog posts, or notebook exports. Every cell carries a tooltip with its row
range and exact missing percentage.

```julia
missinghtml(tbl)                                          # returns a String
missinghtml(tbl; title="My Report", emphasis=:missing, missing_color="#ff0000")
missinghtml(tbl; by=:region)                              # same grouping as plotmissing
missinghtml(tbl; show_row_range=true)                     # row-range labels beside the grid
missinghtml("/path/to/report.html", tbl)                  # writes to a file, returns the path
```

### `missingreport` — One object, two media

`missingreport` returns an object that renders itself as the terminal heatmap
under `MIME"text/plain"` and as the HTML heatmap under `MIME"text/html"`. The
same expression therefore shows Unicode in a REPL and a colored, tooltipped
grid in Jupyter or Pluto, with no branching on the caller's side.

```julia
missingreport(tbl)
missingreport(tbl; emphasis=:missing, missing_color="#ff6600")
missingreport(tbl; by=:region)                # grouped in both media
missingreport(tbl; layout=:compact, title="Cohort A")

show(stdout, MIME"text/html"(), missingreport(tbl))   # force one medium
```

It accepts the keyword arguments of both `plotmissing` and `missinghtml`, and
forwards each only to the renderer that takes it — so per-medium defaults (a
200×60 HTML grid vs a 50×20 terminal grid) survive unless you override them.
An unknown keyword is an error immediately, not at display time.

`plotmissing` and `missinghtml` are unchanged and remain the direct,
single-medium entry points.

## Getting the numbers out

Every view has a data counterpart returning a plain
[Tables.jl](https://github.com/JuliaData/Tables.jl)-compatible row table
(`Vector{<:NamedTuple}`) — no display compression, no `max_patterns`/`max_cols`
cap, nothing printed. They share the same kernels as the renderers, so a number
read here can never disagree with the one drawn on screen.

| Function | One row per | Key fields |
|---|---|---|
| `missingstats` | column | `column`, `eltype`, `nmissing`, `npresent`, `nrows`, `pct` |
| `missingpatternstats` | unique missingness pattern | `pattern` (a `NamedTuple` of `Bool` keyed by column), `nmissing`, `n`, `pct` |
| `missingpairstats` | unordered pair of columns | `a`, `b`, `phi`, `jaccard`, `n11`, `n1`, `n2`, `nrows` |
| `missingrowstats` | observed missing-count | `nmissing`, `nrows`, `pct` |
| `missingdropstats` | column-drop step | `ndropped`, `dropped`, `ncols`, `complete`, `pct`, `cells` |
| `missingsentinels` | candidate sentinel value | `column`, `value`, `n`, `pct`, `reason` |
| `missingpredictors` | other column | `column`, `kind`, `test`, `statistic`, `df`, `pvalue`, `effect`, `n_missing`, `n_present`, `detail` |

```julia
using DataFrames

df = DataFrame(age    = [34, missing, 51, missing, 29],
               income = [missing, 4200, 5100, missing, 3300],
               city   = ["SP", "RJ", "BH", "SP", missing])

DataFrame(missingstats(df))                   # straight into a DataFrame
filter(r -> r.pct > 20, missingstats(df))     # columns worse than 20% missing

# most co-missing column pairs — `first` rather than `[1:5]`, which would
# throw on a table with fewer than five pairs
first(sort(missingpairstats(df); by = r -> -r.phi), 5)

ps = missingpatternstats(df)
filter(r -> r.pattern.age && !r.pattern.income, ps)   # age missing, income present
filter(r -> r.nmissing == 0, ps)                      # the complete-case pattern

rs = missingrowstats(df)
only(r.nrows for r in rs if r.nmissing == 0)  # complete-case count
sum(r.nrows for r in rs if r.nmissing > 0)    # rows lost to listwise deletion
```

`missingpairstats` returns **both** ϕ and Jaccard rather than selecting one
with a `method` keyword: both fall out of the same `n11`/`n1`/`n2` counts, so
the schema stays fixed regardless of which you read. Undefined coefficients
are `NaN` — `phi` whenever a column is entirely missing or entirely present,
`jaccard` only when neither column has a single missing value.

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
- **Sentinel-aware** (`isna`) — count `9`, `99`, `""` or any other coded absence as missing, as public microdata does
- **Column ordering** (`order=:cluster`) — put co-missing columns side by side so the block structure is visible
- **Pattern detection** (`missingpatterns`) and **pairwise correlation** (`missingcooccurrence`) of missingness
- **Before/after diffing** (`plotmissingdiff`) for auditing imputation steps
- **Row-completeness distribution** (`missingrows`) — what listwise deletion costs
- **Listwise-deletion trade-off** (`missingdrop`) — which column to drop to buy back complete rows
- **Little's MCAR test** (`missingmcar`) — the formal check of missing completely at random
- **Sentinel detection** (`missingsentinels`, `sentinelisna`) — find the `9`s, `""`s and `"NA"`s that mean "missing", and turn them into `isna`
- **Predictors of missingness** (`missingpredictors`) — which variables a column's missingness depends on
- **Tables.jl data API** (`missingstats`, `missingpatternstats`, `missingpairstats`, `missingrowstats`, `missingdropstats`) — every view also available as data
- **HTML export** (`missinghtml`) for reports and notebooks
- **Medium-aware display** (`missingreport`) — terminal in the REPL, HTML in Jupyter/Pluto
- **IO-customizable output** — render to `stdout`, a file, or an `IOBuffer`
- **TTY-aware ANSI/truecolor coloring** — colors enabled only where supported

## References

The methods this package implements, and the work it follows. Each entry says
where in the package it is used.

**Missing-data mechanisms**

- Rubin, D. B. (1976). Inference and missing data. *Biometrika*, 63(3),
  581–592. <https://doi.org/10.1093/biomet/63.3.581> — the MCAR / MAR / MNAR
  distinction the diagnostics are read against.
- Little, R. J. A., & Rubin, D. B. (2019). *Statistical Analysis with Missing
  Data* (3rd ed.). Wiley. <https://doi.org/10.1002/9781119482260> — the
  standard reference for the field, including listwise deletion
  (`missingrows`, `missingdrop`) and maximum-likelihood estimation under
  missing data.

**Little's MCAR test** (`missingmcar`)

- Little, R. J. A. (1988). A test of missing completely at random for
  multivariate data with missing values. *Journal of the American Statistical
  Association*, 83(404), 1198–1202.
  <https://doi.org/10.1080/01621459.1988.10478722> — the test statistic and its
  χ² reference distribution.
- Dempster, A. P., Laird, N. M., & Rubin, D. B. (1977). Maximum likelihood from
  incomplete data via the EM algorithm. *Journal of the Royal Statistical
  Society: Series B*, 39(1), 1–22.
  <https://doi.org/10.1111/j.2517-6161.1977.tb01600.x> — the EM estimates of
  the mean and covariance the test compares against.
- Anderson, T. W. (1957). Maximum likelihood estimates for a multivariate
  normal distribution when some observations are missing. *Journal of the
  American Statistical Association*, 52(278), 200–203.
  <https://doi.org/10.1080/01621459.1957.10501379> — the closed-form estimates
  for a monotone pattern, which the test suite checks EM against.
- Press, W. H., Teukolsky, S. A., Vetterling, W. T., & Flannery, B. P. (2007).
  *Numerical Recipes: The Art of Scientific Computing* (3rd ed.), §6.2.
  Cambridge University Press. — §6.2, the series and continued-fraction
  evaluation of the incomplete gamma function behind the χ² p-values; §6.4, the
  incomplete beta function behind the t p-values of `missingpredictors`.
- Lanczos, C. (1964). A precision approximation of the gamma function.
  *Journal of the Society for Industrial and Applied Mathematics, Series B:
  Numerical Analysis*, 1(1), 86–96. <https://doi.org/10.1137/0701008> — the
  log-gamma used by the incomplete beta function.

**Predictors of missingness** (`missingpredictors`)

- Welch, B. L. (1947). The generalization of 'Student's' problem when several
  different population variances are involved. *Biometrika*, 34(1–2), 28–35.
  <https://doi.org/10.1093/biomet/34.1-2.28> — the unequal-variance t-test and
  its degrees of freedom.
- Pearson, K. (1900). On the criterion that a given system of deviations from
  the probable in the case of a correlated system of variables is such that it
  can be reasonably supposed to have arisen from random sampling. *The London,
  Edinburgh, and Dublin Philosophical Magazine and Journal of Science*,
  50(302), 157–175. <https://doi.org/10.1080/14786440009463897> — the χ² test
  of independence.
- Cramér, H. (1946). *Mathematical Methods of Statistics*. Princeton
  University Press. <https://doi.org/10.1515/9781400883868> — Cramér's V.
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences*
  (2nd ed.). Lawrence Erlbaum; reprinted 2013, Routledge.
  <https://doi.org/10.4324/9780203771587> — the standardized mean difference
  and its conventional 0.2 / 0.5 / 0.8 benchmarks.

**Patterns and co-occurrence** (`missingpatterns`, `missingcooccurrence`, `order=:cluster`)

- van Buuren, S., & Groothuis-Oudshoorn, K. (2011). mice: Multivariate
  imputation by chained equations in R. *Journal of Statistical Software*,
  45(3). <https://doi.org/10.18637/jss.v045.i03> — `md.pattern()`, the
  pattern table `missingpatterns` reproduces.
- Lex, A., Gehlenborg, N., Strobelt, H., Vuillemot, R., & Pfister, H. (2014).
  UpSet: Visualization of intersecting sets. *IEEE Transactions on
  Visualization and Computer Graphics*, 20(12), 1983–1992.
  <https://doi.org/10.1109/TVCG.2014.2346248> — the frequency bars beside each
  pattern.
- Yule, G. U. (1912). On the methods of measuring association between two
  attributes. *Journal of the Royal Statistical Society*, 75(6), 579–652.
  <https://doi.org/10.2307/2340126> — the ϕ coefficient of two binary
  attributes, here the missingness masks.
- Jaccard, P. (1912). The distribution of the flora in the alpine zone. *New
  Phytologist*, 11(2), 37–50.
  <https://doi.org/10.1111/j.1469-8137.1912.tb05611.x> — the Jaccard index of
  the missing-row sets.
- Hahsler, M., Hornik, K., & Buchta, C. (2008). Getting things in order: An
  introduction to the R package seriation. *Journal of Statistical Software*,
  25(3). <https://doi.org/10.18637/jss.v025.i03> — seriation, of which
  `order=:cluster` is a greedy nearest-neighbour instance.

**Calendar grouping** (`period=:week`)

- ISO 8601-1:2019. *Date and time — Representations for information
  interchange — Part 1: Basic rules.* International Organization for
  Standardization. — the week numbering and week-based year.

**Sentinel detection** (`missingsentinels`) has no reference: its rules are
this package's own heuristic, written out on the *Methods* page of the documentation.

**Related software**

- Tierney, N., & Cook, D. (2023). Expanding tidy data principles to facilitate
  missing data exploration, visualization and assessment of imputations.
  *Journal of Statistical Software*, 105(7).
  <https://doi.org/10.18637/jss.v105.i07> — `naniar`, the R package for the
  same exploration, including a Little's test (`mcar_test`).

## How to cite

### 1. The software

The repository ships a [`CITATION.cff`](CITATION.cff), which GitHub reads
natively: the **"Cite this repository"** button in the sidebar generates ready
APA and BibTeX. A [`CITATION.bib`](CITATION.bib) is also provided:

```bibtex
@software{bertuzzi_missingpatterns_2026,
  author  = {Bertuzzi, Dante},
  title   = {{MissingPatterns.jl}: terminal-based exploration of missing
             data patterns in {Julia}},
  year    = {2026},
  version = {0.7.0},
  doi     = {10.5281/zenodo.22217099},
  url     = {https://github.com/dantebertuzzi/MissingPatterns.jl},
  note    = {Julia package}
}
```

**Cite the version you used**, not "the latest". What the package reports is
part of your result, and it has changed between releases: `plotmissing`'s
`period` default became `nothing` in 0.4.0, the data API and `missingrows`
arrived in 0.5.0, `isna` and `missingdrop` in 0.6.0 — and 0.6.0 also fixed
`period=:week`, which until then merged ISO weeks across a year boundary. In
0.7.0 grouping with `by` stopped drawing the `by` column itself, which changes
the totals of every grouped plot, and `missingmcar` arrived.
`missingpairstats` reports ϕ and Jaccard side by side where
`missingcooccurrence` shows one at a time. Run `pkg> status
MissingPatterns` and use the number it prints.

**Cite the method too.** The package implements published methods, and a result
reported from one is the method's as much as the software's: a `missingmcar`
p-value is Little's (1988) test, a pattern table is `md.pattern()` (van Buuren
& Groothuis-Oudshoorn, 2011), a ϕ matrix is Yule's (1912) coefficient. The
[References](#references) list says which work backs which function.

### 2. Reproducibility

MissingPatterns.jl reads data, it does not supply any — so there is no
upstream source to cite alongside it, unlike a package that downloads a
public database. What makes a missingness figure reproducible is the input
plus the environment. So that someone else reaches your numbers, record: the
**MissingPatterns.jl and Julia versions**; the `Project.toml` and
`Manifest.toml` of the environment (the `Manifest.toml` pins the whole
dependency tree and is what makes it reconstructible with
`Pkg.instantiate()`); and the dataset itself — its own citation, version or
extraction date, and any filtering applied before the table reached this
package, since dropping rows changes every count reported here.

If you reproduce a figure rather than a number, note the keywords too:
`layout`, `max_rows`/`max_cols` and `by`/`period` determine how rows are
compressed into blocks, so two calls on the same data can render differently.
The [Data API](#getting-the-numbers-out) returns the uncompressed numbers and
is the more citable form.

### The standards behind this

| Standard | What it establishes |
|---|---|
| [FORCE11 — Software Citation Principles](https://force11.org/info/software-citation-principles-published-2016/) | Software is a citable research product. Six principles: importance, credit, unique identification, persistence, accessibility and **specificity** (cite the exact version). |
| [Citation File Format (CFF) 1.2.0](https://citation-file-format.github.io/) | Machine-readable citation metadata. What GitHub and Zenodo consume. |
| [Zenodo + GitHub](https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content) | Mints a persistent DOI per release, plus a *concept DOI* always pointing at the newest version. |

**The DOIs of this project**: the repository is connected to
[Zenodo](https://zenodo.org), so every release is archived and gets a
persistent identifier — the citation no longer depends on the GitHub URL
surviving a rename or a transfer. Two DOIs coexist, and they are not
interchangeable:

| DOI | What it identifies |
|---|---|
| [10.5281/zenodo.22217099](https://doi.org/10.5281/zenodo.22217099) | *Concept DOI* — the project as a whole. Always resolves to the newest version; it is what the badge at the top of this README points at. |
| one per release | Each archived version gets its own — 0.5.1 is [10.5281/zenodo.22217708](https://doi.org/10.5281/zenodo.22217708). All of them are listed on the [Zenodo page](https://doi.org/10.5281/zenodo.22217099). |

The BibTeX above carries the concept DOI, so it keeps working across releases.
**In a paper, swap it for the DOI of the version you used**: the concept DOI
says which project you used, the version DOI says which code actually ran.
