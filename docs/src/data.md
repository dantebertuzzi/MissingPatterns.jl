# Data API

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
