# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-07-04

### Added
- `missingpatterns([io], df; max_patterns=20, ...)`: displays the unique
  row-wise missingness patterns found in a DataFrame, sorted by frequency —
  i.e. which columns tend to be missing *together* (the same diagnostic as
  R's `mice::md.pattern()`). Complements `plotmissing`, which shows
  *where*/*how much* is missing.
- `compute_missing_stats` and `compute_pattern_stats`: internal (non-exported)
  pure calculation functions, now decoupled from rendering, that return
  plain, `@inferred`-testable structs (`MissingGridStats`, `PatternStats`).

### Changed
- Internal architecture split into two independently testable stages:
  calculation (DataFrame → stats struct, no IO) and rendering (stats → IO,
  no data-shape logic). No change to `plotmissing`'s public behavior.
- Missing-value scanning no longer materializes an `nrows × ncols` matrix;
  it accumulates directly into display-sized blocks in a single pass per
  column, bounded by `max_rows × max_cols` regardless of DataFrame size.
- Per-cell rendering writes characters directly to the output buffer instead
  of building and discarding temporary `String`s (`repeat(...)` calls) —
  substantially fewer allocations on large/wide DataFrames.
- Removed the unused `Statistics` dependency.

### Fixed
- Fully-missing cells now always use the same color regardless of whether
  the display was compressed (previously inconsistent: solid red when
  uncompressed vs. gradient red when compressed).

### Development note
This release (refactor + `missingpatterns` feature) was developed with the
assistance of a generative AI coding tool, used as a pair-programming aid.
All generated code was reviewed, benchmarked against the previous
implementation for correctness and performance, and tested by the
maintainer before release, per the Julia community's request for upfront
disclosure of AI-assisted contributions.

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