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

## Notebooks

Three notebooks run in Google Colab with nothing to install — pick the Julia
runtime under *Runtime ▸ Change runtime type*. Each is committed with the
outputs of a real run, so it also reads on GitHub.

| Notebook | What it does |
|---|---|
| [`getting-started.ipynb`](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/getting-started.ipynb) | The tour, on a table whose missingness was put there on purpose: every entry point, `isna`, grouping, the data API and an audited imputation. |
| [`whats-new-0.7.ipynb`](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/whats-new-0.7.ipynb) | What 0.7 adds: [`missingmcar`](@ref), [`missingpredictors`](@ref), [`missingsentinels`](@ref), pattern ordering, `exclude_by`, HTML row labels and keyed diffs. |
| [`obis-missingness.ipynb`](https://colab.research.google.com/github/dantebertuzzi/MissingPatterns.jl/blob/main/notebooks/obis-missingness.ipynb) | The same diagnostics on live marine biodiversity records from OBIS. |

## Functions

| Function | What it shows | Page |
|---|---|---|
| `plotmissing` | *Where*/*how much* is missing (heatmap) | [Heatmaps](@ref) |
| `plotmissingdiff` | Before/after diff (e.g. auditing an imputation step) | [Heatmaps](@ref) |
| `missingpatterns` | *Which columns* go missing *together* | [Diagnostics](@ref) |
| `missingsummary` | Per-column counts, % and a distribution sparkline | [Diagnostics](@ref) |
| `missingcooccurrence` | Pairwise ϕ/Jaccard correlation of missingness masks | [Diagnostics](@ref) |
| `missingrows` | *How many* values are missing per row | [Diagnostics](@ref) |
| `missingdrop` | Which column to drop to buy back complete rows | [Diagnostics](@ref) |
| `missingmcar` | Little's test of missing completely at random | [Diagnostics](@ref) |
| `missingsentinels` | Values that probably encode absence, ready for `isna` | [Diagnostics](@ref) |
| `missingpredictors` | What a column's missingness depends on | [Diagnostics](@ref) |
| `missinghtml` | The heatmap as a standalone HTML fragment | [Export and output](@ref) |
| `missingreport` | The heatmap as an object that renders itself per medium | [Export and output](@ref) |

Every display above has a data counterpart that returns a Tables.jl-compatible
row table instead of printing — see [Data API](@ref).

Full docstrings are in the [Public API](@ref) reference, every formula is on
the [Methods](@ref) page, and the work behind them is on [References](@ref).

## How to cite

Every release is archived on Zenodo. The repository ships a `CITATION.cff`
(which GitHub's *Cite this repository* button reads) and a `CITATION.bib`:

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

Two DOIs coexist and are not interchangeable: the *concept DOI*
[10.5281/zenodo.22217099](https://doi.org/10.5281/zenodo.22217099) identifies
the project as a whole and always resolves to the newest version, while each
release gets its own (0.5.1 is
[10.5281/zenodo.22217708](https://doi.org/10.5281/zenodo.22217708)). **Cite
the version you actually ran** — what the package reports has changed between
releases. See the
[README](https://github.com/dantebertuzzi/MissingPatterns.jl#how-to-cite) for
the reproducibility checklist.
