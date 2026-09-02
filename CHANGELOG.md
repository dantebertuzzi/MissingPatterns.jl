# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-09-02

### Added
- `isna` — the predicate deciding what counts as an absent value, on every
  entry point (`plotmissing`, `missingpatterns`, `missingcooccurrence`,
  `missingsummary`, `missingrows`, `missingdrop`, `plotmissingdiff`,
  `missinghtml`, `missingreport`, the whole data API and the calculation
  kernels). It defaults to `ismissing`, so nothing changes unless you ask.
  Public microdata rarely uses `missing`: DATASUS, the TSE and most
  statistical files code absence as a sentinel — `9`/`99` for "ignored", `""`
  for a blank field — and those tables previously read as fully complete.

  ```julia
  # one predicate for every column
  plotmissing(df; isna = x -> ismissing(x) || x == 9 || x == "")

  # or, preferably, per column — a NamedTuple or a Dict, with `ismissing`
  # assumed for any column left out
  plotmissing(df; isna = (criterio = x -> ismissing(x) || x == 9,
                          cid      = x -> ismissing(x) || x == ""))
  ```

  Prefer the per-column form: a sentinel belongs to a variable, not to a
  table. `9` means "ignored" in a coded field but is a perfectly good age,
  and a blanket predicate punches holes in every column that happens to hold
  the value. Naming a column the table does not have raises rather than being
  silently ignored, so a typo cannot masquerade as a complete table.

  Test `ismissing` first and let `||` short-circuit: `missing == 9` is
  `missing`, not `false`. The predicate applies to every count the package
  makes, the `by` column included, where a sentinel forms the `∅` group just
  as `missing` does. Per-column resolution happens once per column, on the
  dispatch-heavy side of the existing function barriers, and the predicate is
  taken as a type parameter, so the inner loop specializes on it. That turned
  out to make the default path *faster*, not slower: on a 200k×25 table
  `compute_missing_stats` goes from 13.4 ms to 7.7 ms at identical allocations
  (45 KB), because the predicate now reaches the loop as a compile-time
  constant. Output is byte-identical to 0.5.1 across randomized tables.
- `order` on `plotmissing` and `missinghtml` (and so on `missingreport`):
  `:table` (default, unchanged), `:missing` (emptiest columns first), `:name`
  (alphabetical) and `:cluster`. `:cluster` seriates the ϕ matrix so columns
  that go missing *together* sit side by side — table order usually scatters
  them, hiding the block structure the plot exists to show. Columns with no
  missing values carry no pattern and are appended at the end, so a complete
  column never splits a block in half. Reordering is display-only: no count,
  percentage or total changes. When columns are compressed, a reordered group
  is labeled by its endpoint names rather than by positional indices, which
  would otherwise refer to display slots instead of to the table.
- `missingdrop` and `missingdropstats` — the listwise-deletion trade-off.
  `missingrows` prices complete-case analysis for the table as it stands;
  these price the alternative and name the column worth trading. They walk
  the greedy path — at each step dropping the column that turns the most rows
  complete — and report what survives `dropmissing` after each drop, flagging
  the step that maximizes `complete × columns left`. The search runs on the
  deduplicated pattern table rather than on the rows, so the whole path costs
  `O(npatterns * ncols^2)` with no re-scan of the data.

### Fixed
- `_table_info` inferred `Vector{Union{}}` for the column names of a table with
  no columns, which failed the `::Vector{String}` signature of every kernel
  that takes them. Reached only through the new per-column `isna` validation,
  but the annotation was wrong for empty tables either way.
- `period=:week` grouped rows by `(Dates.year, Dates.week)`. `Dates.week` is
  the ISO-8601 week number, whose week-year can differ from the calendar year
  at the turn of the year, so `2024-01-04` (ISO 2024-W01) and `2024-12-30`
  (ISO 2025-W01) both produced the key `(2024, 1)` and were silently folded
  into a single `2024-W01` group — two groups a year apart merged into one, on
  a chart whose whole point is the time axis. The key now uses the ISO
  week-year, so weekly grouping is correct across year boundaries and labels
  read `2025-W01` for that December date. Affects `plotmissing`,
  `missinghtml`, `missingreport` and `compute_missing_stats_grouped` with
  `period=:week`; no other period was affected.
- `missinghtml` escaped column names but not row labels. Under `by`, those
  labels come straight from the data, so a value containing `"` closed the
  cell's `title` attribute early and the rest of the value was parsed as
  markup, corrupting the document. Row labels are now escaped like every other
  interpolated string.
- `compute_missing_stats` threw `DivideError` on a table with no rows and more
  than `max_cols` columns: compression was triggered by the column count, and
  the row divisor `min(nrows, max_rows)` was then zero. It now compares
  against the cap directly — the same idiom the grouped kernel already used —
  and reports `0.0` rather than `NaN` for the per-column header percentage of
  an empty table. The exported entry points all guard against empty tables, so
  this only affected direct calls to the calculation kernel.

### Changed
- `CITATION.cff` and the README/docs DOI tables now name v0.5.1's archive,
  [10.5281/zenodo.22217708](https://doi.org/10.5281/zenodo.22217708),
  alongside the unchanged concept DOI. `identifiers:` lists the concept DOI
  and the current version only — every release is archived separately and the
  full list lives on the Zenodo page.

## [0.5.1] - 2026-09-01

### Fixed
- Two published examples threw when run verbatim. `missingpairstats`'s
  "most co-missing pairs" example indexed the result with `[1:5]`, which
  raises `BoundsError` on any table with fewer than five column pairs (i.e.
  fewer than four columns); it now uses `first(..., 5)`, which clamps.
  `missingpatternstats`'s example filtered on `r.pattern.age`/`r.pattern.income`
  against an undefined `df`, so pasting it against a table with different
  column names raised `FieldError`. Both example blocks (README, docs and
  docstrings) now define the table they operate on, so they can be pasted and
  run as-is.
- The documented examples are now executed by the test suite, so a published
  example that throws fails CI like any other bug.

### Added
- DOI. Releases are archived on Zenodo; the concept DOI
  [10.5281/zenodo.22217099](https://doi.org/10.5281/zenodo.22217099) covers
  the software across all versions and v0.5.0's own snapshot is
  [10.5281/zenodo.22217100](https://doi.org/10.5281/zenodo.22217100). Recorded
  in `CITATION.cff` (concept DOI in `doi:`, version DOI under `identifiers:`)
  and shown as a badge in the README.
- `CITATION.bib` — ready-to-paste BibTeX entry, alongside the `CITATION.cff`
  that GitHub's "Cite this repository" button reads.
- README gained a `How to cite` section: the BibTeX entry, why the version
  used should be cited rather than "the latest", a reproducibility checklist,
  and the distinction between the concept DOI and the per-release DOIs. Same
  layout as the sibling packages (MicroSUS.jl, DeBRief.jl).

### Changed
- Documentation split from a single `index.md` into seven pages (Home,
  Heatmaps, Diagnostics, Data API, Export and output, Public API, Internals).
  The single page had reached 106.6 KiB generated, past Documenter's
  `size_threshold_warn` of 100 KiB and heading for the 200 KiB hard limit at
  which the build fails outright.
- The API reference is now split in two: `Public API` (`Private = false`)
  carries the exported surface, `Internals` (`Public = false`) the documented
  non-exported helpers, which previously sat interleaved with the public
  functions in one list.

## [0.5.0] - 2026-08-31

### Added
- **Data API** — every view now has a counterpart that *returns* a
  Tables.jl-compatible row table (`Vector{<:NamedTuple}`) instead of printing,
  so results can go straight into a `DataFrame`, be filtered, joined or
  serialized. Until now the package was print-only.
  - `missingstats(tbl)` — one row per column: `column`, `eltype`, `nmissing`,
    `npresent`, `nrows`, `pct`.
  - `missingpatternstats(tbl)` — one row per unique missingness pattern:
    `pattern` (a `NamedTuple` of `Bool` keyed by column name), `nmissing`,
    `n`, `pct`. Frequency-ordered, with no `max_patterns`/`min_pct` cap.
  - `missingpairstats(tbl)` — one row per unordered column pair: `a`, `b`,
    `phi`, `jaccard`, `n11`, `n1`, `n2`, `nrows`. No `max_cols` cap. Both
    coefficients are returned rather than selected by a `method` keyword —
    they fall out of the same counts, so the schema stays fixed.
  - `missingrowstats(tbl)` — one row per observed missing-count.

  These share the same kernels as the renderers (`compute_pattern_stats`,
  `_cooccurrence_counts`, `_phi`/`_jaccard`), so a number read through the
  data API can never disagree with the same number drawn on screen.
- `missingrows([io], tbl; sortby, bar_width, color, missing_color)` — the
  transposed view the package was missing: the distribution of *how many*
  values are missing per row. The `0` line is the complete-case count, and
  the rest is what listwise deletion (`dropmissing`) would discard.
  Complements `missingsummary` (per column) and `missingpatterns` (per
  combination).
- `missingreport(tbl; kwargs...)` and the `MissingReport` type — an object
  that renders itself as the terminal heatmap under `MIME"text/plain"` and
  as the HTML heatmap under `MIME"text/html"`, so the same expression shows
  Unicode in a REPL and a colored, tooltipped grid in Jupyter/Pluto. It takes
  the keyword arguments of both `plotmissing` and `missinghtml` and forwards
  each only to the renderer that accepts it, preserving per-medium defaults;
  an unknown keyword raises at construction, not at display time.

  A `show` method for `MIME"text/html"` cannot be attached to the caller's
  table type — defining one for `DataFrame` would be type piracy, which the
  new Aqua check rejects — hence a type this package owns.
- `missinghtml` gained the `by`/`period` keywords, grouping rows by a
  column's values exactly as `plotmissing` does, so a grouped report reads
  the same in both media. Cell tooltips drop the `rows ` prefix when the
  labels are categories or calendar periods rather than row ranges.
- `CITATION.cff` — machine-readable citation metadata, so GitHub renders a
  "Cite this repository" entry and reference managers can import it.
- `.zenodo.json` — deposition metadata (title, abstract, creators, MIT license,
  keywords) used by Zenodo when it archives a GitHub release and mints the DOI.
  Without it, Zenodo would infer everything from the repository alone.
- Aqua.jl added to the test suite (`Aqua.test_all`): checks for stale/unused
  dependencies, missing compat bounds, method ambiguities, unbound type
  parameters, undefined exports and type piracy.

### Removed
- **`CSV` dropped from `[deps]`.** It was declared as a dependency but never
  loaded by `src/` — only mentioned in docstrings as an example of a
  Tables.jl source. Installing MissingPatterns no longer pulls in CSV.jl and
  its transitive dependencies (Parsers, InlineStrings, SentinelArrays,
  PooledArrays, WeakRefStrings, WorkerUtilities). No behavior change: any
  `CSV.File` still works, since it is consumed through the Tables.jl interface.

### Changed
- `compute_cooccurrence`'s ϕ/Jaccard arithmetic factored out into `_phi` and
  `_jaccard`, and its `n1`/`n11` accumulation into `_cooccurrence_counts`, so
  the renderer and the new `missingpairstats` compute from one shared
  implementation instead of two copies. No behavior change — verified value
  for value against the rendered matrix in the test suite.

### Fixed
- `Project.toml`: declared the missing `DataFrames` and `Test` compat bounds
  for the test target (flagged by Aqua).

## [0.4.0] - 2026-08-08

### Added
- **Categorical grouping**: `plotmissing`/`compute_missing_stats_grouped`'s
  `by` kwarg now also accepts non-temporal columns. With `period=nothing`
  (the new default), rows are grouped by the `by` column's exact value —
  sorted with `isless`, so any `String`, `Symbol`, `Int`, etc. column works —
  instead of requiring a `Date`/`DateTime` column and a calendar `period`.
  Existing temporal grouping (`period=:year`/`:quarter`/`:month`/`:week`/`:day`)
  is unchanged.

### Changed
- **Possibly breaking**: `plotmissing`'s `period` keyword default changed
  from `:year` to `nothing`. Only affects callers that pass `by=` without
  also passing `period=`; every documented usage already passed both.
- `compute_missing_stats_grouped` now keys its internal row-grouping
  `Dict`/`Vector` on the period's concrete `Union{K,Nothing}` type instead of
  `Any`, avoiding per-row boxing/dynamic dispatch in the grouping loop.
- `compute_cooccurrence` computes only the upper triangle of its symmetric
  `n11`/`M` matrices and mirrors the result, instead of doing the full
  `ncols × ncols` work twice.
- `plotmissing` no longer resolves the table's columns twice when
  `layout=:auto` is combined with `by`.
- Internal cell-rendering helpers deduplicated (`_colored_cell!` merged into
  `_cell!`; the repeated "color prefix/suffix only if color is on" logic
  factored into one helper). No behavior change.

### Fixed
- `_pattern_keys_general` (the `>64`-column fallback used internally by
  `compute_pattern_stats`/`compute_cooccurrence`) no longer allocates an
  intermediate `BitMatrix` and copies it out row by row.
- `Project.toml`: declared the missing `Dates` compat bound.

### Development note
Test coverage extended for the `by` + `layout=:compact` interaction, the
wide-table (`>64` columns) fallback path of `compute_cooccurrence`, and
`@inferred` checks on the pure calculation functions.

## [0.3.0] - 2026-07-11

### Added
- **Tables.jl migration**: all functions now accept any Tables.jl-compatible source
  (NamedTuples, CSV.File, row tables, etc.), not just DataFrames.
- `missingsummary([io], tbl; sortby, bins, color)`: per-column missing-value
  summary with distribution sparklines.
- `missingcooccurrence([io], tbl; method, max_cols, color)`: pairwise correlation
  (ϕ or Jaccard) of missingness masks between columns.
- `plotmissingdiff([io], before, after; color)`: side-by-side diff heatmap
  showing resolved/introduced missing values between two versions of a dataset.
- `missinghtml([path], tbl; title, emphasis, missing_color)`: HTML heatmap
  export with inline CSS, suitable for reports and notebooks.
- `compute_missing_stats_grouped(tbl, by, period)`: temporal grouping by year,
  quarter, month, week, or day — aggregates rows into period buckets.
- **Compact layout**: `plotmissing(layout=:compact)` renders a space-efficient
  grid using half-block characters (▀) with truecolor RGB foreground/background.
- `layout=:auto`: automatically chooses classic or compact layout based on data
  size and `target_lines`.
- `color` / `emphasis` / `missing_color` kwargs: control ANSI/truecolor cell
  coloring; `emphasis` can highlight `:missing` or `:present` cells.
- `target_lines` kwarg: sets the maximum number of lines for compact layout.
- `_PRESENT_RGB`, `ColorRamp`, `_ramp_rgb`, `_blend`: truecolor gradient system
  for smooth visual transitions, including micro-hole visibility at very low
  missingness rates.

### Changed
- **Breaking**: `plotmissing` no longer requires DataFrames.jl; any Tables.jl
  source is accepted. DataFrames.jl moved to test-only dependency.
- Compact layout uses truecolor RGB escape codes for half-block rendering.
- Progress bar adapts to terminal width via `displaysize`.

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