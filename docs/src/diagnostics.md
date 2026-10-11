# Diagnostics

Three complementary questions about the same missingness, plus the per-row
view:

- [`missingpatterns`](@ref) — *which combinations* of columns go missing together.
- [`missingcooccurrence`](@ref) — the same question as a pairwise correlation.
- [`missingsummary`](@ref) — the per-column marginals.
- [`missingrows`](@ref) — the per-row marginals.
- [`missingdrop`](@ref) — what dropping a column buys complete-case analysis.
- [`missingmcar`](@ref) — Little's test of missing completely at random.

## `missingpatterns` — Unique missingness patterns

Shows *which combinations* of columns are missing together —
the same diagnostic as R's `mice::md.pattern()`.
Patterns are sorted most-frequent first.

```julia
missingpatterns(tbl)
missingpatterns(tbl; max_patterns=10, min_pct=5.0)
missingpatterns(tbl; color_cells=true, emphasis=:missing)
missingpatterns(tbl; show_bar=false)           # hide frequency bar
missingpatterns(tbl; order=:cluster)           # co-missing columns side by side
```

`order` takes the same values as in [`plotmissing`](@ref) (`:table`,
`:missing`, `:name`, `:cluster`). With `:cluster`, each pattern's missing cells
read as one contiguous run instead of scattered marks; the order is computed
from the pattern table itself, at no extra pass over the data.

```julia
```

## `missingsummary` — Per-column missing summary

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

## `missingcooccurrence` — Pairwise correlation of missingness

Computes ϕ (phi) coefficient or Jaccard index between every pair of columns
based on their missingness masks. Positive values indicate columns tend to be
missing *together*.

```julia
missingcooccurrence(tbl)
missingcooccurrence(tbl; method=:jaccard)       # Jaccard instead of ϕ
missingcooccurrence(tbl; max_cols=10)            # cap displayed columns
missingcooccurrence(tbl; color=:always)
```

## `missingrows` — Per-row completeness

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

## `missingdrop` — What dropping a column buys

`missingrows` prices listwise deletion for the table as it stands. The question
that follows is the one you act on: *which* column is buying that cost, and
what does complete-case analysis look like without it. A single sparse column
often accounts for most of the loss.

`missingdrop` walks the greedy path — at each step removing the column that
turns the most rows complete — and reports what survives `dropmissing` after
each one.

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

Read the flagged row: dropping `lab` alone takes complete-case analysis from
626 rows to 940, at the price of one variable. The flag marks the step that
maximizes `complete × columns left` — the size of the surviving complete-case
block — since past that point each drop costs more in columns than it returns
in rows. Whether that trade is worth making is a modeling judgment the package
does not make for you; it only prices it.

The walk stops once every row is complete or one column is left. Use
[`missingdropstats`](@ref) for the same numbers as data.

## `missingmcar` — Little's MCAR test

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
