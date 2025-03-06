# MissingPatterns
![Logo do MissingPatterns.jl](https://raw.githubusercontent.com/dantebertuzzi/MissingPatterns.jl/main/logo.png)
`MissingPatterns` is a Julia package designed to visualize missing data patterns in DataFrames. It provides a simple and intuitive way to identify and analyze missing values in your datasets using heatmaps.

## Installation

To install the `MissingPatterns` package, open Julia and run:

```
using Pkg
Pkg.add("MissingPatterns")
```

## Usage
### Basic Example

```
using DataFrames
using MissingPatterns

# Create a sample DataFrame with missing values
df = DataFrame(A = [1, 2, missing, 4], B = [missing, 2, 3, 4], C = [1, missing, missing, 4])

# Plot missing patterns in vertical orientation
plotmissing(df, orientation=:vertical)

# Plot missing patterns in horizontal orientation
plotmissing(df, orientation=:horizontal)
```
#### Customizing the Plot
You can customize the appearance of the plot using various keyword arguments:

- `plot_size`: Tuple specifying the size of the plot (default: (1000, 800)).

- `orientation`: Symbol (`:vertical` or `:horizontal`) to set the orientation of the plot (default: `:vertical`).

- `dpi`: Integer specifying the resolution of the plot (default: 100).

- `color_missing`: Color for missing values (default: `:grey10`).

- `color_present`: Color for non-missing values (default: `:white`).

- `line_color`: Color for grid lines (default: `:white`).

- `line_width`: Width of grid lines (default: 1).

- `tick_step`: Step size for ticks on the axes (default: 5).

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dantebertuzzi.github.io/MissingPatterns.jl/dev)
[![Build Status](https://github.com/dantebertuzzi/MissingPatterns.jl/workflows/CI/badge.svg)](https://github.com/dantebertuzzi/MissingPatterns.jl/actions)
[![Coverage](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/dantebertuzzi/MissingPatterns.jl)
