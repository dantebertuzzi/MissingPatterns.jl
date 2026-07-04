"""
    MissingPatterns

A terminal-based text heatmap for visualizing missing data patterns in DataFrames,
with zero plotting-library dependencies.

`plotmissing` and `missingpatterns` are exported. See their docstrings for usage.
"""
module MissingPatterns

using Printf
using DataFrames

export plotmissing, missingpatterns

# =============================================================================
# Validation & small pure helpers
# =============================================================================

function _validate_style_params(cell_chars, name_width)
    cell_chars > 0  || throw(ArgumentError("cell_chars must be positive, got $cell_chars"))
    cell_chars <= 80 || throw(ArgumentError("cell_chars too large (max 80), got $cell_chars"))
    name_width >= 0  || throw(ArgumentError("name_width must be >= 0, got $name_width"))
    nothing
end

function _validate_display_params(max_rows, max_cols)
    max_rows > 0   || throw(ArgumentError("max_rows must be positive, got $max_rows"))
    max_cols > 0   || throw(ArgumentError("max_cols must be positive, got $max_cols"))
    nothing
end

"""
    _use_color(io::IO) -> Bool

Canonical ecosystem convention for color-aware output: defer to the `:color`
property of `io` via `get(io, :color, false)`. On Julia >= 1.11 this already
resolves correctly for a raw `Base.TTY` (terminfo-based detection is wired
into `Base.get` for `TTY`). For older Julia versions (down to the package's
`1.6` floor) a raw, unwrapped `TTY` doesn't carry that information yet, so we
conservatively fall back to `io isa Base.TTY`. Callers who want to force (or
suppress) color regardless of `io`'s concrete type should wrap it explicitly,
e.g. `IOContext(io, :color => true)` — exactly as any other Base/ecosystem
`show`-like function expects.
"""
function _use_color(io::IO)
    get(io, :color, false) === true && return true
    return io isa Base.TTY
end

function _prop_to_char(prop::Float64)
    prop <= 0.05 && return '·'
    prop <= 0.15 && return '░'
    prop <= 0.30 && return '▒'
    prop <= 0.50 && return '▓'
    return '█'
end

"""
    _cell_glyph(prop, char_missing, char_present) -> Char

Single source of truth for "which glyph represents this block's missing
fraction", used uniformly whether or not the display was compressed. For an
uncompressed cell `prop` is always exactly `0.0` or `1.0`, so this naturally
degrades to `char_present`/`char_missing` with no special-casing needed.
"""
@inline function _cell_glyph(prop::Float64, char_missing::Char, char_present::Char)
    prop <= 0.0 && return char_present
    prop >= 1.0 && return char_missing
    return _prop_to_char(prop)
end

function _cell_color(prop::Float64)
    prop <= 0.0 && return ""
    prop <= 0.05 && return "\033[32m"
    prop <= 0.15 && return "\033[33m"
    prop <= 0.30 && return "\033[38;5;214m"
    prop <= 0.50 && return "\033[38;5;202m"
    prop <= 0.75 && return "\033[31m"
    return "\033[38;5;196m"
end

function _trunc_name(name, width)
    width == 0 && return name
    length(name) > width || return name
    return string(first(name, width), '…')
end

# =============================================================================
# STAGE 1 — Calculation (pure, no IO): DataFrame -> MissingGridStats
# =============================================================================

"""
    MissingGridStats

Immutable, purely numeric/string result of scanning a DataFrame for missing
values. Contains everything the renderer needs and nothing about *how* it
will be drawn (no IO, no colors, no character choices). This separation is
what makes the calculation independently unit-testable — no ANSI-stripping
regexes required.

Fields:
- `nrows`, `ncols`: original DataFrame dimensions.
- `dr`, `dc`: displayed grid dimensions (== `nrows`/`ncols` when uncompressed).
- `rows_per_cell`, `cols_per_cell`: how many original rows/cols each block spans.
- `needs_compression`: whether any grouping occurred.
- `proportions`: `dr × dc` matrix, missing-fraction of each displayed block.
- `col_header_pct`: length-`dc` vector, % missing across each column group
  (full row range), used for the header row.
- `colnames`: length-`dc` display names (already range-joined when compressed).
- `row_labels`: length-`dr` row-range labels (empty if not requested).
- `missing_count`, `total_cells`: whole-DataFrame totals (not display-bounded).
"""
struct MissingGridStats
    nrows::Int
    ncols::Int
    dr::Int
    dc::Int
    rows_per_cell::Int
    cols_per_cell::Int
    needs_compression::Bool
    proportions::Matrix{Float64}
    col_header_pct::Vector{Float64}
    colnames::Vector{String}
    row_labels::Vector{String}
    missing_count::Int
    total_cells::Int
end

"""
    _accumulate_column!(block_counts, col, rows_per_cell) -> Int

Single pass over one DataFrame column, tallying missing values both into the
per-row-block `block_counts` accumulator and into a running column total
(returned). `col` arrives as a concrete-eltype `AbstractVector` because
`compute_missing_stats` calls this through a per-column dynamic dispatch —
this is the classic Julia "function barrier": the outer loop over
heterogeneous DataFrame columns pays dynamic dispatch once per *column*, while
everything inside this function specializes and compiles for that column's
concrete type, giving fully type-stable, `@simd`-friendly scalar code with no
`Union{T,Missing}` boxing in the hot inner loop.
"""
@inline function _accumulate_column!(block_counts::AbstractVector{Int},
                                      col::AbstractVector,
                                      rows_per_cell::Int)
    total = 0
    @inbounds for i in eachindex(col)
        m = ismissing(col[i]) ? 1 : 0
        total += m
        block_row = div(i - 1, rows_per_cell) + 1
        block_counts[block_row] += m
    end
    return total
end

"""
    compute_missing_stats(df; max_rows, max_cols, show_row_range) -> MissingGridStats

Compute all display-independent statistics for `df` in a single pass per
column, without ever materializing an `nrows × ncols` missing-value matrix.
Memory footprint is `O(dr*dc + dc + nrows_or_dr)` — bounded by the *display*
size (`max_rows × max_cols`), not by the size of `df` itself.
"""
function compute_missing_stats(df::AbstractDataFrame;
                                max_rows::Int, max_cols::Int, show_row_range::Bool)
    nrows, ncols = size(df)
    needs_compression = nrows > max_rows || ncols > max_cols

    rows_per_cell = needs_compression ? cld(nrows, min(nrows, max_rows)) : 1
    cols_per_cell = needs_compression ? cld(ncols, min(ncols, max_cols)) : 1
    dr = cld(nrows, rows_per_cell)
    dc = cld(ncols, cols_per_cell)

    block_counts = zeros(Int, dr, dc)
    col_missing_total = zeros(Int, dc)
    src_colnames = string.(names(df))

    for (j, col) in enumerate(eachcol(df))
        jc = div(j - 1, cols_per_cell) + 1
        col_missing_total[jc] += _accumulate_column!(view(block_counts, :, jc), col, rows_per_cell)
    end

    missing_count = sum(col_missing_total)
    total_cells = nrows * ncols

    proportions = Matrix{Float64}(undef, dr, dc)
    col_header_pct = Vector{Float64}(undef, dc)
    colnames = Vector{String}(undef, dc)

    for jc in 1:dc
        cs = (jc - 1) * cols_per_cell + 1
        ce = min(jc * cols_per_cell, ncols)
        group_width = ce - cs + 1
        col_header_pct[jc] = 100 * col_missing_total[jc] / (nrows * group_width)
        colnames[jc] = cs == ce ? src_colnames[cs] : string(cs, "-", ce)
        for ir in 1:dr
            rs = (ir - 1) * rows_per_cell + 1
            re = min(ir * rows_per_cell, nrows)
            block_size = (re - rs + 1) * group_width
            proportions[ir, jc] = block_counts[ir, jc] / block_size
        end
    end

    row_labels = String[]
    if show_row_range
        row_labels = Vector{String}(undef, dr)
        for ir in 1:dr
            rs = (ir - 1) * rows_per_cell + 1
            re = min(ir * rows_per_cell, nrows)
            row_labels[ir] = rs == re ? string(rs) : string(rs, "-", re)
        end
    end

    return MissingGridStats(nrows, ncols, dr, dc, rows_per_cell, cols_per_cell,
                             needs_compression, proportions, col_header_pct,
                             colnames, row_labels, missing_count, total_cells)
end

# =============================================================================
# STAGE 1b — Calculation (pure, no IO): DataFrame -> PatternStats
#
# Complements `compute_missing_stats` (which answers "where/how much is
# missing") by answering "which columns go missing *together*" — the same
# diagnostic as R's `mice::md.pattern()`. Grouping is inherently row-wise, so
# unlike the heatmap stage we can't avoid visiting every (row, col) pair once;
# what we *can* avoid is ever materializing an `nrows × ncols` matrix: each
# row's missingness signature is packed into a single `UInt64` bitmask (fast
# path, ncols <= 64 — comfortably covers this package's own `max_cols`
# philosophy) or, for wider frames, a `BitMatrix` (1 bit/entry, still 8x
# lighter than `Matrix{Bool}`).
# =============================================================================

const _PATTERN_KEY_BITS = 64

"""
    PatternStats

Pure result of `compute_pattern_stats`: the set of *unique* row-wise
missingness signatures found in a DataFrame, sorted by descending frequency
(ties broken by first appearance in the data, so results are deterministic
across runs regardless of hashing/iteration order).

Fields:
- `nrows`, `ncols`: original DataFrame dimensions.
- `pattern_missing::BitMatrix`: `npatterns × ncols`; `true` = missing in that pattern.
- `counts::Vector{Int}`: row count matching each pattern (same order as `pattern_missing`).
- `colnames::Vector{String}`.
"""
struct PatternStats
    nrows::Int
    ncols::Int
    pattern_missing::BitMatrix
    counts::Vector{Int}
    colnames::Vector{String}
end

# Fast path (ncols <= 64): one UInt64 per row, built via the same
# function-barrier trick as `_accumulate_column!` — dynamic dispatch happens
# once per column, the inner per-row loop is fully specialized/type-stable.
@inline function _or_missing_bit!(keys::Vector{UInt64}, col::AbstractVector, bit::UInt64)
    @inbounds for i in eachindex(col)
        if ismissing(col[i])
            keys[i] |= bit
        end
    end
    return nothing
end

function _pattern_keys_fast(df::AbstractDataFrame, nrows::Int)
    keys = zeros(UInt64, nrows)
    for (j, col) in enumerate(eachcol(df))
        _or_missing_bit!(keys, col, UInt64(1) << (j - 1))
    end
    return keys
end

# General fallback (ncols > 64): bit-packed BitMatrix, then one BitVector
# view per row for grouping. Same O(nrows*ncols) time as the fast path, just
# without the single-word packing trick — a deliberate simplicity/performance
# tradeoff since wide (>64-column) frames are a rare case for this package.
@inline function _fill_missing_bits!(dest::AbstractVector{Bool}, col::AbstractVector)
    @inbounds for i in eachindex(col)
        dest[i] = ismissing(col[i])
    end
    return nothing
end

function _pattern_keys_general(df::AbstractDataFrame, nrows::Int, ncols::Int)
    mask = BitMatrix(undef, nrows, ncols)
    for (j, col) in enumerate(eachcol(df))
        _fill_missing_bits!(view(mask, :, j), col)
    end
    return [mask[i, :] for i in 1:nrows]
end

@inline function _unpack_key!(dest::AbstractVector{Bool}, k::UInt64)
    @inbounds for j in eachindex(dest)
        dest[j] = (k >> (j - 1)) & 0x1 == 0x1
    end
    return nothing
end

@inline function _unpack_key!(dest::AbstractVector{Bool}, k::BitVector)
    @inbounds for j in eachindex(dest)
        dest[j] = k[j]
    end
    return nothing
end

"""
    compute_pattern_stats(df::AbstractDataFrame) -> PatternStats

Compute the unique row-wise missingness patterns of `df` and their
frequencies, sorted most-common first.
"""
function compute_pattern_stats(df::AbstractDataFrame)
    nrows, ncols = size(df)
    colnames = string.(names(df))

    row_keys = ncols <= _PATTERN_KEY_BITS ?
        _pattern_keys_fast(df, nrows) :
        _pattern_keys_general(df, nrows, ncols)

    K = eltype(row_keys)
    counts = Dict{K,Int}()
    first_seen = Dict{K,Int}()
    for (i, k) in enumerate(row_keys)
        if haskey(counts, k)
            counts[k] += 1
        else
            counts[k] = 1
            first_seen[k] = i
        end
    end

    unique_keys = collect(Base.keys(counts))
    sort!(unique_keys; by = k -> (-counts[k], first_seen[k]))

    npatterns = length(unique_keys)
    pattern_missing = falses(npatterns, ncols)
    pattern_counts = Vector{Int}(undef, npatterns)
    for (idx, k) in enumerate(unique_keys)
        pattern_counts[idx] = counts[k]
        _unpack_key!(view(pattern_missing, idx, :), k)
    end

    return PatternStats(nrows, ncols, pattern_missing, pattern_counts, colnames)
end

# =============================================================================
# STAGE 2 — Rendering (IO only, no data-shape decisions)
# =============================================================================

"""
    RenderStyle

Everything the renderer needs about *how* to draw, precomputed once up front
(border strings, cell width, ANSI codes) so the per-cell hot loop only ever
reads plain fields — no recomputation, no closures capturing mutable state.
"""
struct RenderStyle
    cell_chars::Int
    char_missing::Char
    char_present::Char
    name_width::Int
    color_cells::Bool
    show_row_range::Bool
    use_color::Bool
    cw::Int
    rw::Int
    hbar::String
    row_bar::String
    rst::String
    blue::String
    orange::String
end

"""
    _make_render_style(io; cell_chars, char_missing, char_present, name_width,
                        color_cells, show_row_range=false, row_labels=String[])

Builds a [`RenderStyle`](@ref) up front (border strings, cell width, ANSI
codes). Deliberately decoupled from `MissingGridStats` — it only needs
`row_labels` to size the optional row-range column — so it can be reused by
any renderer in this package (currently the heatmap grid and the pattern
table), not just `plotmissing`.
"""
function _make_render_style(io::IO; cell_chars::Int, char_missing::Char, char_present::Char,
                             name_width::Int, color_cells::Bool,
                             show_row_range::Bool=false, row_labels::Vector{String}=String[])
    cw = max(cell_chars + 2, 9)
    hbar = repeat("━", cw)

    rw = 0
    row_bar = ""
    if show_row_range
        rw = max(5, maximum(length, row_labels))
        row_bar = repeat("━", rw)
    end

    use_color = _use_color(io)
    rst    = use_color ? "\033[0m" : ""
    blue   = use_color ? "\033[34m" : ""
    orange = use_color ? "\033[38;5;208m" : ""

    return RenderStyle(cell_chars, char_missing, char_present, name_width, color_cells,
                        show_row_range, use_color, cw, rw, hbar, row_bar, rst, blue, orange)
end

# --- Zero-allocation primitives -------------------------------------------
#
# `write(io, ::Char)` is allocation-free (it encodes the codepoint directly
# into io's buffer). Building `repeat(' ', n)` / `repeat(char, n)` strings
# just to immediately `print` and discard them is pure GC pressure — these
# tiny loops replace every such call in the hot rendering path.

@inline function _write_spaces!(buf::IO, n::Int)
    @inbounds for _ in 1:n
        write(buf, ' ')
    end
    return nothing
end

@inline function _write_repeated!(buf::IO, c::Char, n::Int)
    @inbounds for _ in 1:n
        write(buf, c)
    end
    return nothing
end

function _hborder!(buf::IO, dc::Int, hbar::String, row_bar::String,
                    show_row_range::Bool, left::Char, mid::Char, right::Char)
    write(buf, left)
    if show_row_range
        write(buf, row_bar)
        write(buf, mid)
    end
    for k in 1:dc
        k > 1 && write(buf, mid)
        write(buf, hbar)
    end
    write(buf, right)
    write(buf, '\n')
    return nothing
end

function _row_label!(buf::IO, text::AbstractString, rw::Int)
    pad = rw - length(text)
    pl = div(pad, 2)
    _write_spaces!(buf, pl)
    write(buf, text)
    _write_spaces!(buf, pad - pl)
    return nothing
end

function _cell!(buf::IO, content::AbstractString, cw::Int)
    n = length(content)
    if n > cw - 2
        content = first(content, cw - 2)
        n = cw - 2
    end
    pt = cw - n
    pl = div(pt, 2)
    _write_spaces!(buf, pl)
    write(buf, content)
    _write_spaces!(buf, pt - pl)
    return nothing
end

"""
    _data_cell!(buf, glyph, cell_chars, cw, prefix, suffix)

Writes one heatmap data cell directly to `buf`: padding, optional ANSI
prefix/suffix, and the glyph repeated `cell_chars` times — with zero
intermediate `String` allocations (compare to the original
`repeat(string(char), cell_chars)` + double `repeat(' ', pad)` per cell).
Since `cw = max(cell_chars + 2, 9)` by construction, `cell_chars <= cw - 2`
always holds, so (unlike `_cell!`) no truncation branch is needed here.
"""
function _data_cell!(buf::IO, glyph::Char, cell_chars::Int, cw::Int,
                      prefix::String, suffix::String)
    pt = cw - cell_chars
    pl = div(pt, 2)
    _write_spaces!(buf, pl)
    isempty(prefix) || write(buf, prefix)
    _write_repeated!(buf, glyph, cell_chars)
    isempty(suffix) || write(buf, suffix)
    _write_spaces!(buf, pt - pl)
    return nothing
end

function render_grid!(buf::IO, stats::MissingGridStats, style::RenderStyle)
    dc, dr = stats.dc, stats.dr
    cw, rw = style.cw, style.rw
    hbar, row_bar = style.hbar, style.row_bar
    show_row_range = style.show_row_range

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┏', '┳', '┓')

    write(buf, '┃')
    if show_row_range
        _row_label!(buf, "", rw)
        write(buf, '┃')
    end
    for j in 1:dc
        _cell!(buf, @sprintf("%3d%%", round(Int, stats.col_header_pct[j])), cw)
        write(buf, '┃')
    end
    write(buf, '\n')

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┣', '╋', '┫')

    write(buf, '┃')
    if show_row_range
        _row_label!(buf, "row", rw)
        write(buf, '┃')
    end
    for j in 1:dc
        _cell!(buf, _trunc_name(stats.colnames[j], style.name_width), cw)
        write(buf, '┃')
    end
    write(buf, '\n')

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┣', '╋', '┫')

    cell_color_on = style.color_cells && style.use_color

    for i in 1:dr
        write(buf, '┃')
        if show_row_range
            _row_label!(buf, stats.row_labels[i], rw)
            write(buf, '┃')
        end
        for j in 1:dc
            prop = stats.proportions[i, j]
            glyph = _cell_glyph(prop, style.char_missing, style.char_present)
            if cell_color_on
                prefix = _cell_color(prop)
                suffix = isempty(prefix) ? "" : style.rst
            else
                prefix = ""
                suffix = ""
            end
            _data_cell!(buf, glyph, style.cell_chars, cw, prefix, suffix)
            write(buf, '┃')
        end
        write(buf, '\n')
    end

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┗', '┻', '┛')
    return nothing
end

function render_summary!(buf::IO, stats::MissingGridStats, style::RenderStyle, io::IO)
    nrows, ncols = stats.nrows, stats.ncols
    missing_count = stats.missing_count
    total_cells = stats.total_cells
    present_count = total_cells - missing_count
    missing_pct = 100 * missing_count / total_cells
    present_pct = 100 - missing_pct

    rst, blue, orange = style.rst, style.blue, style.orange

    print(buf, "MissingPatterns.Analysis: ", blue, nrows, rst, " × ", blue, ncols, rst, " DataFrame")
    write(buf, '\n')

    if stats.needs_compression
        print(buf, " Compression: ", blue, nrows, rst, "×", blue, ncols, rst,
              " → ", blue, stats.dr, rst, "×", blue, stats.dc, rst,
              " cells  ┊ Ratio: ", blue, stats.rows_per_cell, rst, "×",
              blue, stats.cols_per_cell, rst, " per cell")
    else
        print(buf, " Compression: No compression needed                    ┊ Ratio: ",
              blue, "1", rst, "×", blue, "1", rst, " per cell")
    end
    write(buf, '\n')

    mc_str = lpad(string(missing_count), 14)
    pc_str = lpad(string(present_count), 14)
    mp_str = lpad(@sprintf("%.2f", missing_pct), 13)
    pp_str = lpad(@sprintf("%.2f", present_pct), 13)

    print(buf, " Missing (count):  ", blue, mc_str, rst,
          "               ┊ Missing (", orange, '%', rst, "):  ",
          blue, mp_str, rst, orange, '%', rst)
    write(buf, '\n')
    print(buf, " Present (count):  ", blue, pc_str, rst,
          "               ┊ Present (", orange, '%', rst, "):  ",
          blue, pp_str, rst, orange, '%', rst)
    write(buf, '\n')

    tw = try
        displaysize(io)[2]
    catch
        80
    end
    bw = clamp(tw - 22, 20, 120)
    mb = round(Int, bw * missing_pct / 100)
    pb = bw - mb
    print(buf, " Progress Bar:     ", blue, '[', rst)
    if mb > 0
        write(buf, orange)
        _write_repeated!(buf, '█', mb)
        write(buf, rst)
    end
    if pb > 0
        write(buf, blue)
        _write_repeated!(buf, '█', pb)
        write(buf, rst)
    end
    print(buf, blue, ']', rst)
    write(buf, '\n')
    return nothing
end

"""
    render_pattern_table!(buf, stats, style, max_patterns) -> Int

Draws the pattern table for `stats`, reusing the exact same border/cell
primitives as `render_grid!` (`_hborder!`, `_cell!`, `_data_cell!`,
`_cell_glyph`, `_cell_color`) — one row per unique missingness pattern
(already sorted most-common first), one column per variable plus trailing
`n`/`%` columns. At most `max_patterns` rows are drawn (`stats.counts` is
sorted descending, so the most informative patterns are always shown first).
Returns how many patterns were actually rendered, so the caller can report
how many (if any) were omitted.
"""
function render_pattern_table!(buf::IO, stats::PatternStats, style::RenderStyle, max_patterns::Int)
    ncols = stats.ncols
    dc = ncols + 2  # + "n" + "%" columns
    cw, hbar = style.cw, style.hbar
    shown = min(max_patterns, length(stats.counts))

    _hborder!(buf, dc, hbar, "", false, '┏', '┳', '┓')

    write(buf, '┃')
    for j in 1:ncols
        _cell!(buf, _trunc_name(stats.colnames[j], style.name_width), cw)
        write(buf, '┃')
    end
    _cell!(buf, "n", cw); write(buf, '┃')
    _cell!(buf, "%", cw); write(buf, '┃')
    write(buf, '\n')

    _hborder!(buf, dc, hbar, "", false, '┣', '╋', '┫')

    cell_color_on = style.color_cells && style.use_color
    for i in 1:shown
        write(buf, '┃')
        for j in 1:ncols
            prop = stats.pattern_missing[i, j] ? 1.0 : 0.0
            glyph = _cell_glyph(prop, style.char_missing, style.char_present)
            if cell_color_on
                prefix = _cell_color(prop)
                suffix = isempty(prefix) ? "" : style.rst
            else
                prefix = ""
                suffix = ""
            end
            _data_cell!(buf, glyph, style.cell_chars, cw, prefix, suffix)
            write(buf, '┃')
        end
        _cell!(buf, string(stats.counts[i]), cw); write(buf, '┃')
        pct = 100 * stats.counts[i] / stats.nrows
        _cell!(buf, @sprintf("%.1f%%", pct), cw); write(buf, '┃')
        write(buf, '\n')
    end

    _hborder!(buf, dc, hbar, "", false, '┗', '┻', '┛')
    return shown
end

# =============================================================================
# Public API
# =============================================================================

"""
    plotmissing([io::IO=stdout], df; cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false, show_row_range=false, max_rows=50, max_cols=20)

Display a text-based heatmap of missing value patterns in a DataFrame.
When the dataset exceeds the display limits, multiple rows/columns are grouped
into a single cell using a Unicode block-character gradient.

# Arguments
- `io::IO`: output stream (default: `stdout`).
- `df::AbstractDataFrame`: input DataFrame.
- `cell_chars::Int`: number of repeated characters per heatmap cell (default: 5, max: 80).
- `char_missing::Char`: character for fully-missing cells (default: `'█'`).
- `char_present::Char`: character for fully-present cells (default: `'░'`).
- `name_width::Int`: max characters shown for column names before truncating with `…`
  (default: 4; set to 0 to show full names, bounded by cell width).
- `color_cells::Bool`: apply ANSI color gradient to heatmap cells (green→yellow→red).
  Only effective when output is a TTY with color support (default: `false`).
- `show_row_range::Bool`: display original row numbers (or row ranges when compressed)
  in a left-hand column (default: `false`).
- `max_rows::Int`: maximum display rows before compression (default: 50).
- `max_cols::Int`: maximum display columns before compression (default: 20).

# Returns
- `nothing`. The plot is written to `io`.
"""
function plotmissing(io::IO, df::AbstractDataFrame; cell_chars::Int=5,
                     char_missing::Char='█', char_present::Char='░',
                     name_width::Int=4, color_cells::Bool=false,
                     show_row_range::Bool=false,
                     max_rows::Int=50, max_cols::Int=20,
                     char_width::Int=-1)

    if char_width != -1
        Base.depwarn(
            "keyword argument `char_width` is deprecated, use `cell_chars` instead.",
            :plotmissing
        )
        cell_chars = char_width
    end

    _validate_style_params(cell_chars, name_width)
    _validate_display_params(max_rows, max_cols)

    nrows, ncols = size(df)
    if nrows == 0 || ncols == 0
        println(io, "Empty DataFrame — nothing to display")
        return nothing
    end

    stats = compute_missing_stats(df; max_rows, max_cols, show_row_range)
    style = _make_render_style(io; cell_chars, char_missing, char_present, name_width,
                                color_cells, show_row_range, row_labels=stats.row_labels)

    buf = IOBuffer()
    render_grid!(buf, stats, style)
    write(buf, '\n')
    render_summary!(buf, stats, style, io)

    write(io, take!(buf))
    return nothing
end

plotmissing(df::AbstractDataFrame; kwargs...) = plotmissing(stdout, df; kwargs...)

"""
    missingpatterns([io::IO=stdout], df; max_patterns=20, cell_chars=5,
                     char_missing='█', char_present='░', name_width=4, color_cells=false)

Display the unique row-wise missingness patterns found in `df`, sorted by
descending frequency — i.e. *which columns tend to be missing together*.

This complements [`plotmissing`](@ref), which shows *where*/*how much* is
missing: `missingpatterns` shows *which combinations* of missing columns
actually occur, the same diagnostic produced by R's `mice::md.pattern()`.
Useful for reasoning about the missingness mechanism (e.g. if two columns
are always missing together, that's rarely MCAR) and for choosing an
imputation strategy.

# Arguments
- `io::IO`: output stream (default: `stdout`).
- `df::AbstractDataFrame`: input DataFrame.
- `max_patterns::Int`: maximum number of patterns to display, most-frequent
  first (default: 20). Patterns beyond this are summarized in a trailing count.
- `cell_chars::Int`: number of repeated characters per cell (default: 5, max: 80).
- `char_missing::Char`: character for a missing column in a pattern (default: `'█'`).
- `char_present::Char`: character for a present column in a pattern (default: `'░'`).
- `name_width::Int`: max characters shown for column names before truncating with `…`
  (default: 4; set to 0 to show full names, bounded by cell width).
- `color_cells::Bool`: apply the same ANSI coloring as `plotmissing` (default: `false`).

# Returns
- `nothing`. The table is written to `io`.
"""
function missingpatterns(io::IO, df::AbstractDataFrame; max_patterns::Int=20,
                          cell_chars::Int=5, char_missing::Char='█', char_present::Char='░',
                          name_width::Int=4, color_cells::Bool=false)
    _validate_style_params(cell_chars, name_width)
    max_patterns > 0 || throw(ArgumentError("max_patterns must be positive, got $max_patterns"))

    nrows, ncols = size(df)
    if nrows == 0 || ncols == 0
        println(io, "Empty DataFrame — nothing to display")
        return nothing
    end

    stats = compute_pattern_stats(df)
    style = _make_render_style(io; cell_chars, char_missing, char_present, name_width, color_cells)

    buf = IOBuffer()
    shown = render_pattern_table!(buf, stats, style, max_patterns)
    write(buf, '\n')

    npatterns = length(stats.counts)
    print(buf, " ", npatterns, " unique pattern", npatterns == 1 ? "" : "s",
          " across ", stats.nrows, " row", stats.nrows == 1 ? "" : "s")
    if shown < npatterns
        print(buf, "  (showing top ", shown, "; ", npatterns - shown, " more not shown)")
    end
    write(buf, '\n')

    write(io, take!(buf))
    return nothing
end

missingpatterns(df::AbstractDataFrame; kwargs...) = missingpatterns(stdout, df; kwargs...)

end
