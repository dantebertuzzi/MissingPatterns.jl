# Export and output

## `missinghtml` — HTML heatmap export

Generates a standalone HTML heatmap suitable for reports and notebooks.

```julia
missinghtml(tbl)
missinghtml(tbl; title="My Report", emphasis=:missing, missing_color="#ff0000")
missinghtml(tbl; by=:region)                   # same grouping as plotmissing
missinghtml("/path/to/report.html", tbl)
```

## `missingreport` — One object, two media

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
