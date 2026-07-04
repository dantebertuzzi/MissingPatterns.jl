# MissingPatterns
<div align="center">
  <img src="https://raw.githubusercontent.com/dantebertuzzi/MissingPatterns.jl/main/logo.png" alt="Logo do MissingPatterns.jl" width="200">
</div>

`MissingPatterns` is a Julia package designed to visualize missing data patterns in DataFrames. It provides a simple and intuitive way to identify and analyze missing values in your datasets using heatmaps.

## Installation

To install the `MissingPatterns` package, open Julia and run:

```julia
using Pkg
Pkg.add("MissingPatterns")
```

## Usage
### Basic Example

```julia
using DataFrames
using MissingPatterns

# Create a sample DataFrame with missing values
df = DataFrame(A = [1, 2, missing, 4], B = [missing, 2, 3, 4], C = [1, missing, missing, 4])

# Plot missing patterns
plotmissing(df)
```

### Advanced Example with Large Datasets

```julia
# For large datasets (20k+ rows), the package automatically compresses the visualization
# and provides enhanced sensitivity for detecting missing patterns

# Create a large dataset
using Random
Random.seed!(123)

nrows, ncols = 20000, 10
data = [rand() < 0.2 ? missing : rand(1:100) for _ in 1:nrows, _ in 1:ncols]
df_large = DataFrame(data, Symbol.(["Col_$i" for i in 1:ncols]))

# The visualization will show compression info and enhanced sensitivity
plotmissing(df_large)
```

### Customizing the Plot

You can customize the appearance using keyword arguments:

| Argument | Default | Description |
|---|---|---|
| `cell_chars` | `5` | Repeated characters per cell (max: 80) |
| `char_missing` | `'█'` | Character for fully-missing cells |
| `char_present` | `'░'` | Character for fully-present cells |
| `name_width` | `4` | Max chars for column names before truncation (`0` = full) |
| `color_cells` | `false` | ANSI color gradient green→yellow→red |
| `show_row_range` | `false` | Display original row numbers/ranges on the left |
| `max_rows` | `50` | Max display rows before compression |
| `max_cols` | `20` | Max display columns before compression |

#### Row Ranges

```julia
# Show which original rows each display cell represents
plotmissing(df; show_row_range=true)
```

#### ANSI Colors

```julia
# Color cells by missing proportion (green → yellow → red)
plotmissing(df; color_cells=true)
```

#### Custom Characters & Width

```julia
plotmissing(df; char_missing='X', char_present='.')
plotmissing(df; cell_chars=3, name_width=8)
```

#### Redirecting Output

```julia
# Write to a file
open("report.txt", "w") do f
    plotmissing(f, df)
end

# Capture to string
io = IOBuffer()
plotmissing(io, df)
report = String(take!(io))
```

### Enhanced Sensitivity for Large Datasets

For datasets with more than 50 rows, the package automatically compresses the visualization and provides enhanced sensitivity:

- **`·`** (dot): 1-5% missing values
- **`░`** (light square): 5-15% missing values  
- **`▒`** (medium square): 15-30% missing values
- **`▓`** (dark square): 30-50% missing values
- **`█`** (full square): 50%+ missing values

### Features

- **Automatic compression** for large datasets
- **Enhanced sensitivity** to detect subtle missing patterns
- **Visual progress bar** showing missing vs present data
- **Pattern detection** — `missingpatterns` shows which columns go missing *together*
- **Terminal-based visualization** - no external dependencies
- **IO-customizable output** — render to any `IO` (stdout, files, IOBuffer)
- **TTY-aware ANSI coloring** — colors enabled only in interactive terminals

## Missing Data Patterns

While `plotmissing` shows *where*/*how much* is missing, `missingpatterns` shows
*which combinations* of columns tend to be missing together — the same
diagnostic produced by R's `mice::md.pattern()`. This is useful for reasoning
about the missingness mechanism (columns that are always missing together are
rarely MCAR) and for choosing an imputation strategy.

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

Patterns are sorted most-frequent first. `max_patterns` (default `20`) caps how
many rows are displayed; `cell_chars`, `char_missing`, `char_present`,
`name_width` and `color_cells` behave exactly as in `plotmissing`.

[![Stable Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/stable)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/dev)
[![Build Status](https://github.com/dantebertuzzi/MissingPatterns.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/dantebertuzzi/MissingPatterns.jl/actions)
[![Coverage](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl)
[![JuliaHub](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fjuliahub.com%2Fapi%2Fv2%2Fpackages%2FMissingPatterns%2Fversion&query=version&label=version&color=green)](https://juliahub.com/ui/Packages/MissingPatterns/41be38da)
