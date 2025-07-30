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

You can customize the appearance of the plot using various keyword arguments:

- `char_missing`: Character for missing values (default: `'█'`)
- `char_present`: Character for present values (default: `'░'`)
- `char_width`: Width of characters for display (default: `5`)
- `max_rows`: Maximum number of rows to display (default: `50`)
- `max_cols`: Maximum number of columns to display (default: `20`)

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
- **Comprehensive statistics** including row/column analysis
- **Visual progress bar** showing missing vs present data
- **Pattern analysis** identifying complete/empty rows and columns
- **Terminal-based visualization** - no external dependencies

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/dev)
[![Build Status](https://github.com/dantebertuzzi/MissingPatterns.jl/workflows/CI/badge.svg)](https://github.com/dantebertuzzi/MissingPatterns.jl/actions)
[![Coverage](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl)
