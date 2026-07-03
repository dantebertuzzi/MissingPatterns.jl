# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2025-07-03

### Added
- `cell_chars` keyword replacing `char_width` (old name still works with deprecation warning).
- `name_width` keyword for configurable column-name truncation (default: 4; set to 0 for full names).
- `io::IO` parameter for redirecting output (stdout, files, IOBuffer, etc.).
- Auto-disable ANSI colors when output stream is not a TTY.
- Upper bound validation for `cell_chars` (max 80).
- Module-level docstring.

### Changed
- All docstrings translated to English.
- Column name truncation is now Unicode-safe (uses `first()` instead of byte indexing).
- Progress bar width adapts to terminal dimensions.

### Fixed
- Major performance regression: eliminated duplicate `ismissing.(df)` scan.
- IOBuffer-based rendering replaces per-cell `print()` calls (dramatic speedup for large grids).
- Border construction no longer allocates temporary arrays per row.
- ANSI escape codes no longer break `lpad` alignment in summary lines.
- `Printf` added as explicit dependency.
- CI: `MissingPatternss` typo → `MissingPatterns` in doctest job.
- Docs manifest version synced to `0.1.2`.

### Removed
- False claims of "row/column analysis" and "pattern analysis" from README.

## [0.1.2] - 2024-12-19

### Added
- Enhanced sensitivity for large datasets with improved character scale
- New character symbols for better missing pattern detection:
  - `·` (dot): 1-5% missing values
  - `░` (light square): 5-15% missing values
  - `▒` (medium square): 15-30% missing values
  - `▓` (dark square): 30-50% missing values
  - `█` (full square): 50%+ missing values
- Automatic compression information display for large datasets
- Visual progress bar showing missing vs present data proportions

### Changed
- Improved character width default from 3 to 5 for better visibility
- Enhanced compression algorithm for better handling of large datasets
- Updated documentation with examples for large datasets

### Removed
- Removed Plots.jl dependency (now uses only Statistics.jl)
- Removed horizontal orientation functionality to simplify the API

### Fixed
- Fixed DataFrame iteration issues in large datasets
- Improved padding calculation to prevent negative values
- Enhanced error handling for edge cases

## [0.1.1] - 2024-12-19

### Added
- Initial release
- Basic missing pattern visualization
- Support for DataFrames with missing values
- Customizable character symbols and dimensions 