# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Sensitivity information when compression ratio > 100 rows per cell
- Comprehensive statistics including row/column analysis
- Visual progress bar showing missing vs present data proportions
- Pattern analysis identifying complete/empty rows and columns

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