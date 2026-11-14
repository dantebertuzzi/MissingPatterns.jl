# Diagnostics

Three complementary questions about the same missingness, plus the per-row
view:

- [`missingpatterns`](@ref) — *which combinations* of columns go missing together.
- [`missingcooccurrence`](@ref) — the same question as a pairwise correlation.
- [`missingsummary`](@ref) — the per-column marginals.
- [`missingrows`](@ref) — the per-row marginals.
- [`missingdrop`](@ref) — what dropping a column buys complete-case analysis.
- [`missingmcar`](@ref) — Little's test of missing completely at random.
- [`missingsentinels`](@ref) — values that probably encode absence, for `isna`.
- [`missingpredictors`](@ref) — what a column's missingness depends on.
- [`missinggaps`](@ref) — whether the missing values are isolated holes or blocks.

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

With an `io` first argument the result is printed with its reading instead:

```
julia> missingmcar(stdout, tbl; columns=[:age, :income, :lab, :weight])
 Little's MCAR test on 4 columns (age, income, lab, weight)
 d² = 22.45   df = 11   p = 0.021
 ▲ evidence against MCAR at α = 0.05 — the patterns differ systematically, so complete-case analysis is likely biased
 1000 rows used ┊ 6 patterns ┊ EM converged in 16 iterations
```

A small p-value is evidence *against* MCAR, so complete-case analysis is likely
biased. A large one fails to reject it; it does not prove it, and it cannot tell
MAR from MNAR. The test is defined for continuous columns: by default every
column with a real element type is used (`Bool` excluded) and the others are
listed in `skipped` — and on the printed form's second line — so a text or date
column is never left out unnoticed. Rows with nothing observed are left out.
The result also carries the EM estimates (`mu`, `sigma`) and whether EM
converged.

## `missingsentinels` — Absence that does not say `missing`

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
[Methods](@ref) page.

These are **candidates for review**. Keep the ones that are codes and turn
them into the per-column `isna` every other function takes:

```julia
isna = sentinelisna(found)                                  # all of them
isna = sentinelisna(filter(r -> r.column != :age, found))   # all but one column
missingsummary(tbl; isna)
```

## `missingpredictors` — What the missingness depends on

[`missingmcar`](@ref) says *whether* the missingness is related to the data;
`missingpredictors` says *to what*. For one column, every other column is
compared between the rows where it is missing and the rows where it is
present — Welch's t-test for numbers and dates, a χ² test of independence for
everything else — and sorted by p-value. A column that differs predicts the
missingness: that is the working diagnostic for MAR, and the list of variables
an imputation model for the column must include.

```julia
missingpredictors(stdout, tbl, :income; isna)       # printed
rs = missingpredictors(tbl, :income; isna)          # the same rows, as data
missingpredictors(tbl, :income; isna, adjust=:bh)   # Benjamini–Hochberg instead of Holm
```

```
 Missingness of income: 202 of 1000 rows (20.20%)
 column     test             p      p adj  effect              detail
 region     χ²        2.18e-08   1.31e-07    0.20  ██          south: 42.1% of rows where missing vs 20.9% where present
 age        welch t   1.82e-05   9.10e-05   +0.35  ████        mean 60 where missing vs 52.47 where present
 date       welch t      0.242      0.966   +0.09  ░           mean 2022-02-18 where missing vs 2021-12-21 where present
 schooling  welch t      0.700      1.000   +0.03  ░           mean 1.509 where missing vs 1.472 where present
 lab        welch t      0.756      1.000   -0.03  ░           mean 3.429 where missing vs 3.456 where present
 weight     welch t      0.870      1.000   +0.02  ░           mean 60.32 where missing vs 60.15 where present
 2 of 6 tests significant at α = 0.05 after Holm adjustment ┊ effect: standardized mean difference for numbers and dates, Cramér's V otherwise (bar capped at 1)
```

Income is refused more in the south and by older respondents — which is how
this table was built. For numeric columns `effect` is the standardized mean
difference (0.2 small, 0.5 medium, 0.8 large by Cohen's convention); for the
others it is Cramér's V. Dates are compared as dates, which catches what
`missingmcar` cannot: the same call on `:lab` puts `date` first, with
`p = 1.7e-19` and a mean a year earlier where `lab` is missing.

One test is run per column, so with many columns a few unrelated ones will come
out significant by chance. `padj` corrects for that: by default with Holm's
(1979) method, which bounds the chance of *any* false positive;
`adjust=:bh` uses Benjamini & Hochberg (1995), which bounds the expected share
of false positives among the columns declared significant and is the more
powerful with many columns; `:bonferroni` and `:none` are also accepted. The
printed table tints the effect bar of the columns with `padj < alpha`
(default `0.05`). Read the effect sizes alongside: in a large table a tiny
effect is significant even after adjustment.

## `missinggaps` — Isolated holes or blocks

Two columns can both be 10% missing and need opposite treatment: one lost a
value here and there, which interpolation or any imputation handles; the other
lost a contiguous stretch — a sensor down for three weeks, a questionnaire block
a whole wave skipped — with nothing observed nearby to impute from.
`missinggaps` measures the runs of consecutive missing rows in each column, in
table order or in the order of a `by` column:

```julia
missinggaps(tbl)
missinggaps(tbl; by = :date)                 # consecutive in time, not in the file
missinggaps(tbl; breaks = [1, 2, 8, 31])     # length classes 1, 2–7, 8–30, 31+
missinggaps(tbl; sortby = :missing)          # :longest (default), :missing, :gaps, :name, :none
```

On daily weather records:

```
 column   missing    gaps  longest  date                       mean  │ 1   2   3–5 6–10 11–30 31–100 101+
 rain          23       2       22  2024-02-09 … 2024-03-01    11.5  │ ▁▁▁              █████
 wind           8       3        4  2024-04-09 … 2024-04-12     2.7  │ ▁▁▁     ▇▇▇
 temp          17      16        2  2024-02-02 … 2024-02-03     1.1  │ ███ ▁▁▁
 21 gaps across 3 columns (17 isolated) ┊ bars: share of each column's missing values lying in a gap of that length ┊ rows in order of date
```

`temp` and `rain` are missing about as often, but `temp` lost single days —
interpolating them is harmless — while almost all of `rain`'s missing values
sit in one three-week hole. The histogram is weighted by values, not by runs:
each bar is the share of the column's missing values lying in a gap of that
length, so a column's bars always add up to its missing count. With `by`, the
`by` column is left out and the longest gap is reported in its units; rows
where it is `missing` go last. [`missinggapstats`](@ref) returns one row per column with
`ngaps`, `longest`, `longest_start`/`longest_stop` (row numbers of the table),
`mean_length` and `isolated`.
