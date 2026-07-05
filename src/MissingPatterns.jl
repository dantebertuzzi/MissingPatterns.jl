"""
    MissingPatterns

Terminal-based text visualizations for missing data patterns in any
Tables.jl-compatible source (DataFrames, CSV.File, NamedTuples of vectors,
XLSX tables, ...), with zero plotting-library dependencies.

Exported API:
- [`plotmissing`](@ref) — where/how much is missing (heatmap; optional
  temporal grouping via `by`/`period`).
- [`missingpatterns`](@ref) — which columns are missing *together*
  (unique row patterns, à la `mice::md.pattern()`).
- [`missingcooccurrence`](@ref) — pairwise ϕ/Jaccard association of
  missingness masks.
- [`missingsummary`](@ref) — per-column table with counts, % and a
  sparkline of where along the rows the missing values concentrate.
- [`plotmissingdiff`](@ref) — before/after comparison (e.g. auditing an
  imputation step).
- [`missinghtml`](@ref) — the heatmap as a standalone HTML fragment.
"""
module MissingPatterns

using Printf
using Dates
using Tables

export plotmissing, missingpatterns, missingcooccurrence, missingsummary,
       plotmissingdiff, missinghtml

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
    _table_info(tbl) -> (cols, colnames::Vector{String}, nrows, ncols)

Resolve any Tables.jl-compatible source to a column-accessible object plus
its dimensions. This is the single entry point through which every public
function consumes data, so the package works identically for DataFrames,
`CSV.File`, NamedTuples of vectors, `XLSX.gettable` results, etc.
"""
function _table_info(tbl)
    Tables.istable(tbl) || throw(ArgumentError(
        "input of type $(typeof(tbl)) is not a Tables.jl-compatible table " *
        "(DataFrame, CSV.File, NamedTuple of vectors, ...)"))
    cols = Tables.columns(tbl)
    colnames = [String(n) for n in Tables.columnnames(cols)]
    ncols = length(colnames)
    nrows = ncols == 0 ? 0 : length(Tables.getcolumn(cols, 1))
    return cols, colnames, nrows, ncols
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

"""
    ColorRamp

Monochromatic truecolor ramp for cell coloring. `base` is the dark neutral
"no ink" tone, `target` the full color, and `emphasis` decides which side of
the data gets the ink:

- `:present` (default) — present data is painted in `target`; missing data
  fades toward `base`. Holes read as dark gaps in a colored field.
- `:missing` — the inverse: fully-present blocks stay dark, missing data is
  painted in `target`.
"""
struct ColorRamp
    base::NTuple{3,Int}
    target::NTuple{3,Int}
    emphasis::Symbol
end

"""
    _parse_hex(s) -> NTuple{3,Int}

Parse `"#rrggbb"` (leading `#` optional) into an RGB tuple.
"""
function _parse_hex(s::AbstractString)
    h = lstrip(s, '#')
    length(h) == 6 || throw(ArgumentError("missing_color must be \"#rrggbb\", got \"$s\""))
    r = parse(Int, h[1:2]; base=16)
    g = parse(Int, h[3:4]; base=16)
    b = parse(Int, h[5:6]; base=16)
    return (r, g, b)
end

const _PRESENT_RGB = (48, 48, 54)  # dark neutral gray for "no missing"

@inline function _blend(a::NTuple{3,Int}, b::NTuple{3,Int}, t::Float64)
    return (round(Int, a[1] + t * (b[1] - a[1])),
            round(Int, a[2] + t * (b[2] - a[2])),
            round(Int, a[3] + t * (b[3] - a[3])))
end

"""
    _ramp_rgb(ramp, prop) -> NTuple{3,Int}

Map a block's missing fraction `prop` to an RGB color.

Downsampling-fidelity guarantee, in *both* emphasis modes: any `prop > 0`
gets a minimum blend of ~30% away from the fully-present color (with a
square-root scale below that), so a single missing value averaged over
thousands of rows still produces a visibly different shade. Small holes
never vanish under compression.

- `emphasis == :present`: `prop == 0` → full `target` color; increasing
  missingness darkens toward `base` (holes = dark gaps in a colored field).
- `emphasis == :missing`: `prop == 0` → `base`; increasing missingness
  brightens toward `target`.
"""
function _ramp_rgb(ramp::ColorRamp, prop::Float64)
    if ramp.emphasis === :present
        prop <= 0.0 && return ramp.target
        t = 0.30 + 0.70 * sqrt(clamp(prop, 0.0, 1.0))
        return _blend(ramp.target, ramp.base, t)
    else
        prop <= 0.0 && return ramp.base
        t = 0.30 + 0.70 * sqrt(clamp(prop, 0.0, 1.0))
        return _blend(ramp.base, ramp.target, t)
    end
end

"""
    _glyph_prefix(style, prop) -> String

ANSI foreground prefix for a colored *glyph* cell (classic layout and
pattern table). Under `:missing` emphasis, fully-present cells keep the
terminal's default color (historic behavior); under `:present` emphasis
every cell is colored, since present data is exactly what carries the ink.
"""
@inline function _glyph_prefix(style, prop::Float64)
    if style.ramp.emphasis === :missing && prop <= 0.0
        return ""
    end
    return _fg_rgb(_ramp_rgb(style.ramp, prop))
end

@inline _fg_rgb(c::NTuple{3,Int}) = string("\033[38;2;", c[1], ';', c[2], ';', c[3], 'm')
@inline _bg_rgb(c::NTuple{3,Int}) = string("\033[48;2;", c[1], ';', c[2], ';', c[3], 'm')

function _trunc_name(name, width)
    width == 0 && return name
    length(name) > width || return name
    return string(first(name, width), '…')
end

# =============================================================================
# STAGE 1 — Calculation (pure, no IO): table -> MissingGridStats
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
- `row_labels`: length-`dr` row-range (or period-range) labels.
- `row_lo`, `row_hi`: the two endpoints of each row label, kept separate so
  the half-block renderer can splice pair labels ("lo of top – hi of bottom").
- `group_desc`: human-readable grouping description (e.g. `"by DATA (year)"`),
  empty when rows are grouped positionally.
- `missing_count`, `total_cells`: whole-table totals (not display-bounded).
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
    row_lo::Vector{String}
    row_hi::Vector{String}
    group_desc::String
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
    compute_missing_stats(tbl; max_rows, max_cols) -> MissingGridStats

Compute all display-independent statistics for a Tables.jl-compatible `tbl`
in a single pass per column, without ever materializing an `nrows × ncols`
missing-value matrix. Memory footprint is `O(dr*dc + dc + dr)` — bounded by
the *display* size (`max_rows × max_cols`), not by the data itself.
Row-range labels are always built (they are at most `max_rows` tiny strings).
"""
function compute_missing_stats(tbl; max_rows::Int, max_cols::Int)
    cols, src_colnames, nrows, ncols = _table_info(tbl)
    needs_compression = nrows > max_rows || ncols > max_cols

    rows_per_cell = needs_compression ? cld(nrows, min(nrows, max_rows)) : 1
    cols_per_cell = needs_compression ? cld(ncols, min(ncols, max_cols)) : 1
    dr = cld(nrows, rows_per_cell)
    dc = cld(ncols, cols_per_cell)

    block_counts = zeros(Int, dr, dc)
    col_missing_total = zeros(Int, dc)

    for j in 1:ncols
        jc = div(j - 1, cols_per_cell) + 1
        col_missing_total[jc] += _accumulate_column!(view(block_counts, :, jc),
                                                      Tables.getcolumn(cols, j),
                                                      rows_per_cell)
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

    row_lo = Vector{String}(undef, dr)
    row_hi = Vector{String}(undef, dr)
    row_labels = Vector{String}(undef, dr)
    for ir in 1:dr
        rs = (ir - 1) * rows_per_cell + 1
        re = min(ir * rows_per_cell, nrows)
        row_lo[ir] = string(rs)
        row_hi[ir] = string(re)
        row_labels[ir] = rs == re ? row_lo[ir] : string(rs, "-", re)
    end

    return MissingGridStats(nrows, ncols, dr, dc, rows_per_cell, cols_per_cell,
                             needs_compression, proportions, col_header_pct,
                             colnames, row_labels, row_lo, row_hi, "",
                             missing_count, total_cells)
end

# =============================================================================
# STAGE 1b — Calculation (pure, no IO): table -> PatternStats
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

function _pattern_keys_fast(cols, nrows::Int, ncols::Int)
    keys = zeros(UInt64, nrows)
    for j in 1:ncols
        _or_missing_bit!(keys, Tables.getcolumn(cols, j), UInt64(1) << (j - 1))
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

function _pattern_keys_general(cols, nrows::Int, ncols::Int)
    mask = BitMatrix(undef, nrows, ncols)
    for j in 1:ncols
        _fill_missing_bits!(view(mask, :, j), Tables.getcolumn(cols, j))
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
    compute_pattern_stats(tbl) -> PatternStats

Compute the unique row-wise missingness patterns of a Tables.jl-compatible
`tbl` and their frequencies, sorted most-common first.
"""
function compute_pattern_stats(tbl)
    cols, colnames, nrows, ncols = _table_info(tbl)

    row_keys = ncols <= _PATTERN_KEY_BITS ?
        _pattern_keys_fast(cols, nrows, ncols) :
        _pattern_keys_general(cols, nrows, ncols)

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
    ramp::ColorRamp
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
                             show_row_range::Bool=false, row_labels::Vector{String}=String[],
                             force_color::Union{Nothing,Bool}=nothing,
                             missing_color::String="#f3a9a9",
                             emphasis::Symbol=:present)
    cw = max(cell_chars + 2, 9)
    hbar = repeat("━", cw)

    rw = 0
    row_bar = ""
    if show_row_range
        rw = max(5, maximum(length, row_labels))
        row_bar = repeat("━", rw)
    end

    use_color = force_color === nothing ? _use_color(io) : force_color
    rst    = use_color ? "\033[0m" : ""
    blue   = use_color ? "\033[34m" : ""
    orange = use_color ? "\033[38;5;208m" : ""

    ramp = ColorRamp(_PRESENT_RGB, _parse_hex(missing_color), emphasis)

    return RenderStyle(cell_chars, char_missing, char_present, name_width, color_cells,
                        show_row_range, use_color, cw, rw, hbar, row_bar, rst, blue, orange,
                        ramp)
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
                prefix = _glyph_prefix(style, prop)
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

    if !isempty(stats.group_desc)
        print(buf, " Grouping:    ", blue, stats.group_desc, rst,
              " → ", blue, stats.dr, rst, "×", blue, stats.dc, rst, " cells")
    elseif stats.needs_compression
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
    _bar_cell!(buf, ratio, cw, prefix, suffix)

Left-aligned horizontal frequency bar, filling `ratio` of the available
interior width (`cw - 2`) with `'█'`. The rest is spaces. Padding and ANSI
prefix/suffix follow the same convention as `_cell!` and `_data_cell!`.
"""
function _bar_cell!(buf::IO, ratio::Float64, cw::Int, prefix::String, suffix::String)
    interior = cw - 2
    filled = clamp(round(Int, ratio * interior), 0, interior)
    write(buf, ' ')
    isempty(prefix) || write(buf, prefix)
    _write_repeated!(buf, '█', filled)
    _write_spaces!(buf, interior - filled)
    isempty(suffix) || write(buf, suffix)
    write(buf, ' ')
    return nothing
end

"""
    render_pattern_table!(buf, stats, style, max_patterns;
                          show_bar=true, min_pct=0.0) -> (shown, nkept)

Draws the pattern table for `stats`, reusing the exact same border/cell
primitives as `render_grid!` — one row per unique missingness pattern
(already sorted most-common first), one column per variable plus trailing
`n`/`%` columns and, when `show_bar`, an UpSet-style horizontal frequency
bar scaled to the most common displayed pattern. Patterns whose relative
frequency is below `min_pct` (percent of rows) are filtered out before the
`max_patterns` cap is applied. Returns `(shown, nkept)`: how many patterns
were rendered and how many survived the `min_pct` filter, so the caller can
report both kinds of omission.
"""
function render_pattern_table!(buf::IO, stats::PatternStats, style::RenderStyle,
                                max_patterns::Int; show_bar::Bool=true,
                                min_pct::Float64=0.0)
    ncols = stats.ncols
    dc = ncols + 2 + (show_bar ? 1 : 0)  # + "n" + "%" (+ "freq") columns
    cw, hbar = style.cw, style.hbar

    kept = [i for i in eachindex(stats.counts)
            if 100 * stats.counts[i] / stats.nrows >= min_pct]
    nkept = length(kept)
    shown = min(max_patterns, nkept)
    maxc = shown == 0 ? 1 : stats.counts[kept[1]]  # counts sorted descending

    _hborder!(buf, dc, hbar, "", false, '┏', '┳', '┓')

    write(buf, '┃')
    for j in 1:ncols
        _cell!(buf, _trunc_name(stats.colnames[j], style.name_width), cw)
        write(buf, '┃')
    end
    _cell!(buf, "n", cw); write(buf, '┃')
    _cell!(buf, "%", cw); write(buf, '┃')
    if show_bar
        _cell!(buf, "freq", cw); write(buf, '┃')
    end
    write(buf, '\n')

    _hborder!(buf, dc, hbar, "", false, '┣', '╋', '┫')

    cell_color_on = style.color_cells && style.use_color
    bar_prefix = style.use_color ? _fg_rgb(style.ramp.target) : ""
    bar_suffix = style.use_color ? style.rst : ""
    for k in 1:shown
        i = kept[k]
        write(buf, '┃')
        for j in 1:ncols
            prop = stats.pattern_missing[i, j] ? 1.0 : 0.0
            glyph = _cell_glyph(prop, style.char_missing, style.char_present)
            if cell_color_on
                prefix = _glyph_prefix(style, prop)
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
        if show_bar
            _bar_cell!(buf, stats.counts[i] / maxc, cw, bar_prefix, bar_suffix)
            write(buf, '┃')
        end
        write(buf, '\n')
    end

    _hborder!(buf, dc, hbar, "", false, '┗', '┻', '┛')
    return shown, nkept
end

# =============================================================================
# STAGE 2b — Compact rendering (fits an IDE/Jupyter output cell, ~20–30 lines)
#
# Two independent tricks, combined:
#
#   1. *Half-block vertical doubling* — each text line encodes TWO grid rows
#      using '▀': the ANSI foreground color carries the top block's missing
#      fraction, the background color carries the bottom block's. This doubles
#      vertical resolution per line of output, so the same line budget shows
#      twice as many (i.e. twice-as-fine) row blocks.
#
#   2. *Condensed chrome* — one header line ("NAME  p%") instead of three
#      (pct row + separator + name row), and a one-line summary instead of
#      six. Fixed overhead drops from 13 lines to 5.
#
# Net effect for a 191_640-row frame in a 28-line budget: 46 row blocks at
# ~4_166 rows/block, versus ~15 blocks (~12_776 rows/block) if one simply
# lowered `max_rows` on the classic layout. Granularity is further protected
# by `_ramp_rgb`: any block containing at least one missing value renders in a
# color distinct from "fully present", so small holes never vanish.
#
# When color is unavailable (`use_color == false`), half-blocks cannot encode
# two values per character, so the compact layout degrades gracefully to the
# classic glyph gradient (·░▒▓█) at one grid row per line — still with the
# condensed chrome, so it also fits the budget, just at lower resolution.
# =============================================================================

# Fixed non-data lines in the compact layout:
#   top border + header + separator + bottom border + summary  = 5
const _COMPACT_OVERHEAD = 5

"""
    _compact_max_rows(target_lines, halfblock) -> Int

How many *grid rows* fit in `target_lines` total output lines under the
compact layout. With half-blocks each output line carries two grid rows.
"""
function _compact_max_rows(target_lines::Int, halfblock::Bool)
    data_lines = max(target_lines - _COMPACT_OVERHEAD, 1)
    return halfblock ? 2 * data_lines : data_lines
end

"""
    _compact_header_text(name, pct, cw, name_width) -> String

Compose the single compact header cell, e.g. `"PREC 6%"`, guaranteed to fit
in a cell of interior width `cw - 2`. The percentage is never sacrificed;
the name is truncated (with `…`) as needed.
"""
function _compact_header_text(name::String, pcts::String, cw::Int, name_width::Int)
    room = cw - 2 - length(pcts) - 1          # interior − pct − separating space
    nm = name_width > 0 ? _trunc_name(name, name_width) : name
    if length(nm) > room
        nm = room >= 2 ? string(first(nm, room - 1), '…') : String(first(nm, max(room, 0)))
    end
    return isempty(nm) ? pcts : string(nm, ' ', pcts)
end

"""
    _pair_row_label(stats, top, bot) -> String

Row-range (or period-range) label spanning the two grid rows folded into one
half-block line: the low endpoint of `top` joined to the high endpoint of
`bot`. Works uniformly for positional row indices and temporal group labels.
"""
function _pair_row_label(stats::MissingGridStats, top::Int, bot::Int)
    lo, hi = stats.row_lo[top], stats.row_hi[bot]
    return lo == hi ? lo : string(lo, "-", hi)
end

"""
    _halfblock_cell!(buf, fg, bg, cell_chars, cw, rst)

One compact data cell: `cell_chars` copies of '▀' whose ANSI foreground is
the RGB tuple `fg` (top grid row) and background `bg` (bottom grid row).
Color semantics live entirely with the caller, so the same primitive serves
`plotmissing` (missingness ramp) and `plotmissingdiff` (signed delta
colors). `bg` may be `nothing` when the grid has an odd number of rows and this is the
final, unpaired line — the bottom half then keeps the terminal background.
"""
function _halfblock_cell!(buf::IO, fg::NTuple{3,Int}, bg::Union{NTuple{3,Int},Nothing},
                           cell_chars::Int, cw::Int, rst::String)
    pt = cw - cell_chars
    pl = div(pt, 2)
    _write_spaces!(buf, pl)
    write(buf, _fg_rgb(fg))
    bg === nothing || write(buf, _bg_rgb(bg))
    _write_repeated!(buf, '▀', cell_chars)
    write(buf, rst)
    _write_spaces!(buf, pt - pl)
    return nothing
end

"""
    render_grid_compact!(buf, stats, style; halfblock)

Compact grid: condensed chrome always; half-block vertical doubling when
`halfblock` (requires `style.use_color`), classic glyphs otherwise.
"""
function render_grid_compact!(buf::IO, stats::MissingGridStats, style::RenderStyle;
                               halfblock::Bool)
    dc, dr = stats.dc, stats.dr
    cw, rw = style.cw, style.rw
    hbar, row_bar = style.hbar, style.row_bar
    show_row_range = style.show_row_range
    rst = style.use_color ? "\033[0m" : ""

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┏', '┳', '┓')

    write(buf, '┃')
    if show_row_range
        _row_label!(buf, "row", rw)
        write(buf, '┃')
    end
    for j in 1:dc
        _cell!(buf, _compact_header_text(stats.colnames[j],
                                          string(round(Int, stats.col_header_pct[j]), '%'),
                                          cw, style.name_width), cw)
        write(buf, '┃')
    end
    write(buf, '\n')

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┣', '╋', '┫')

    if halfblock
        i = 1
        while i <= dr
            top = i
            bot = i + 1 <= dr ? i + 1 : 0
            write(buf, '┃')
            if show_row_range
                _row_label!(buf, _pair_row_label(stats, top, bot == 0 ? top : bot), rw)
                write(buf, '┃')
            end
            for j in 1:dc
                fgc = _ramp_rgb(style.ramp, stats.proportions[top, j])
                bgc = bot == 0 ? nothing : _ramp_rgb(style.ramp, stats.proportions[bot, j])
                _halfblock_cell!(buf, fgc, bgc, style.cell_chars, cw, rst)
                write(buf, '┃')
            end
            write(buf, '\n')
            i += 2
        end
    else
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
                    prefix = _glyph_prefix(style, prop)
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
    end

    _hborder!(buf, dc, hbar, row_bar, show_row_range, '┗', '┻', '┛')
    return nothing
end

"""
    render_summary_compact!(buf, stats, style)

Single-line summary carrying the same information as `render_summary!`
(dimensions, compression ratio, missing/present counts and percentages).
"""
function render_summary_compact!(buf::IO, stats::MissingGridStats, style::RenderStyle)
    rst, blue, orange = style.rst, style.blue, style.orange
    missing_pct = 100 * stats.missing_count / stats.total_cells
    present_pct = 100 - missing_pct

    print(buf, ' ', blue, stats.nrows, rst, '×', blue, stats.ncols, rst)
    if !isempty(stats.group_desc)
        print(buf, " → ", blue, stats.dr, rst, '×', blue, stats.dc, rst,
              " (", stats.group_desc, ")")
    elseif stats.needs_compression
        print(buf, " → ", blue, stats.dr, rst, '×', blue, stats.dc, rst,
              " (", blue, stats.rows_per_cell, rst, '×', blue, stats.cols_per_cell, rst,
              "/cell)")
    end
    print(buf, " ┊ missing ", orange, @sprintf("%.2f", missing_pct), '%', rst,
          " (", blue, stats.missing_count, rst, ')',
          " ┊ present ", blue, @sprintf("%.2f", present_pct), '%', rst)
    write(buf, '\n')
    return nothing
end

# =============================================================================
# Public API
# =============================================================================

"""
    plotmissing([io::IO=stdout], tbl; cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false, show_row_range=false,
                max_rows=50, max_cols=20,
                layout=:auto, target_lines=28, color=:auto,
                missing_color="#f3a9a9", emphasis=:present,
                by=nothing, period=:year)

Display a text-based heatmap of missing value patterns in any
Tables.jl-compatible source (DataFrame, `CSV.File`, NamedTuple of vectors,
...). When the data exceeds the display limits, multiple rows/columns are
grouped into a single cell using a Unicode block-character gradient
(classic layout) or an ANSI-colored half-block encoding (compact layout).

# Layouts
- `:classic` — the original layout: one grid row per line, 3-line header,
  6-line summary. Best in a full terminal with room to scroll.
- `:compact` — fits the *entire* plot (grid + header + summary) in at most
  `target_lines` lines, so IDE/Jupyter output cells never truncate it.
  With color available, each output line encodes **two** grid rows via `'▀'`
  (foreground = top row, background = bottom row), doubling vertical
  resolution; without color it falls back to the glyph gradient at one row
  per line. Any block containing even a single missing value is rendered in
  a shade distinct from "fully present", so fine holes survive compression.
- `:auto` (default) — uses `:classic` when it fits within `target_lines`,
  `:compact` otherwise.

# Temporal grouping
- `by::Union{Nothing,Symbol,String}`: name of a `Date`/`DateTime` column.
  When set, rows are grouped by the *values* of that column (not by
  position), so the vertical axis becomes honest calendar time and row
  labels show periods (e.g. `2004`, `2013-Q2`). Rows whose `by` value is
  `missing` form a trailing `∅` group. Row labels are always shown in this
  mode. If there are more periods than fit the budget, consecutive periods
  are merged and labeled as ranges.
- `period::Symbol`: `:year` (default), `:quarter`, `:month`, `:week`, `:day`.

# Arguments
- `io::IO`: output stream (default: `stdout`).
- `tbl`: any Tables.jl-compatible table.
- `cell_chars::Int`: number of repeated characters per heatmap cell (default: 5, max: 80).
- `char_missing::Char`: character for fully-missing cells (default: `'█'`).
- `char_present::Char`: character for fully-present cells (default: `'░'`).
- `name_width::Int`: max characters shown for column names before truncating with `…`
  (default: 4; set to 0 to show full names, bounded by cell width).
- `color_cells::Bool`: apply the color ramp to classic-layout glyphs. The
  compact half-block layout always colors its cells (default: `false`).
- `show_row_range::Bool`: display row-range (or period) labels in a
  left-hand column (default: `false`; forced `true` when `by` is set).
- `max_rows::Int`: maximum display rows before compression in the classic
  layout (default: 50). Ignored by `:compact`, which derives its own limit
  from `target_lines`.
- `max_cols::Int`: maximum display columns before compression (default: 20).
- `layout::Symbol`: `:auto`, `:classic`, or `:compact` (default: `:auto`).
- `target_lines::Int`: total line budget for the compact layout, including
  borders, header and summary (default: 28 — safely under typical IDE
  output-cell limits of ~30 lines).
- `color::Symbol`: `:auto` (respect `io`'s `:color` property / TTY detection),
  `:always` (force ANSI codes — use this in VS Code/Jupyter notebooks, whose
  output cells render ANSI but whose `stdout` is not a TTY), or `:never`
  (plain text — use when redirecting to a file).
- `missing_color::String`: hex color (`"#rrggbb"`) of the ramp
  (default: `"#f3a9a9"`).
- `emphasis::Symbol`: which side of the data carries the ink (default:
  `:present`). With `:present`, present data is painted in `missing_color`
  and missing data fades to dark gray — holes read as dark gaps in a
  colored field. With `:missing`, the ramp is inverted. In both modes, any
  block containing even one missing value renders in a shade visibly
  different from a fully-present block.

# Returns
- `nothing`. The plot is written to `io`.
"""
function plotmissing(io::IO, tbl; cell_chars::Int=5,
                     char_missing::Char='█', char_present::Char='░',
                     name_width::Int=4, color_cells::Bool=false,
                     show_row_range::Bool=false,
                     max_rows::Int=50, max_cols::Int=20,
                     layout::Symbol=:auto, target_lines::Int=28,
                     color::Symbol=:auto, missing_color::String="#f3a9a9",
                     emphasis::Symbol=:present,
                     by::Union{Nothing,Symbol,AbstractString}=nothing,
                     period::Symbol=:year,
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
    layout in (:auto, :classic, :compact) ||
        throw(ArgumentError("layout must be :auto, :classic or :compact, got :$layout"))
    color in (:auto, :always, :never) ||
        throw(ArgumentError("color must be :auto, :always or :never, got :$color"))
    emphasis in (:present, :missing) ||
        throw(ArgumentError("emphasis must be :present or :missing, got :$emphasis"))
    target_lines >= _COMPACT_OVERHEAD + 1 ||
        throw(ArgumentError("target_lines must be at least $(_COMPACT_OVERHEAD + 1), got $target_lines"))

    _, _, nrows, ncols = _table_info(tbl)
    if nrows == 0 || ncols == 0
        println(io, "Empty table — nothing to display")
        return nothing
    end

    # Grouping by a temporal column only makes sense with visible labels.
    show_row_range = show_row_range || by !== nothing

    force_color = color === :auto ? nothing : (color === :always)
    use_color = force_color === nothing ? _use_color(io) : force_color

    _stats(mr) = by === nothing ?
        compute_missing_stats(tbl; max_rows=mr, max_cols) :
        compute_missing_stats_grouped(tbl, by, period; max_rows=mr, max_cols)

    # Resolve :auto — classic fits iff its total height (grid rows + 3-line
    # header + 3 border lines + blank + 6-line summary = dr + 13) is within
    # the budget. For grouped data the row count depends on the data, so we
    # compute once with the classic budget and recompute only if compact is
    # chosen with a different row limit.
    stats = nothing
    resolved = layout
    if layout === :auto
        if by === nothing
            classic_dr = cld(nrows, nrows > max_rows || ncols > max_cols ?
                                     cld(nrows, min(nrows, max_rows)) : 1)
            resolved = classic_dr + 13 <= target_lines ? :classic : :compact
        else
            stats = _stats(max_rows)
            resolved = stats.dr + 13 <= target_lines ? :classic : :compact
            resolved === :compact && (stats = nothing)
        end
    end

    if resolved === :compact
        halfblock = use_color
        eff_max_rows = _compact_max_rows(target_lines, halfblock)
        stats === nothing && (stats = _stats(eff_max_rows))
        row_labels = stats.row_labels
        if show_row_range && halfblock
            # Row labels span half-block pairs; rebuild them so the label
            # column is sized for the pair ranges actually printed.
            row_labels = [_pair_row_label(stats, i, min(i + 1, stats.dr))
                          for i in 1:2:stats.dr]
        end
        style = _make_render_style(io; cell_chars, char_missing, char_present, name_width,
                                    color_cells, show_row_range, row_labels, force_color,
                                    missing_color, emphasis)
        buf = IOBuffer()
        render_grid_compact!(buf, stats, style; halfblock)
        render_summary_compact!(buf, stats, style)
        write(io, take!(buf))
        return nothing
    end

    stats === nothing && (stats = _stats(max_rows))
    style = _make_render_style(io; cell_chars, char_missing, char_present, name_width,
                                color_cells, show_row_range, row_labels=stats.row_labels,
                                force_color, missing_color, emphasis)

    buf = IOBuffer()
    render_grid!(buf, stats, style)
    write(buf, '\n')
    render_summary!(buf, stats, style, io)

    write(io, take!(buf))
    return nothing
end

plotmissing(tbl; kwargs...) = plotmissing(stdout, tbl; kwargs...)

"""
    missingpatterns([io::IO=stdout], tbl; max_patterns=20, cell_chars=5,
                     char_missing='█', char_present='░', name_width=4,
                     color_cells=false, missing_color="#f3a9a9",
                     emphasis=:present, show_bar=true, min_pct=0.0)

Display the unique row-wise missingness patterns found in a
Tables.jl-compatible `tbl`, sorted by descending frequency — i.e. *which
columns tend to be missing together*.

This complements [`plotmissing`](@ref), which shows *where*/*how much* is
missing: `missingpatterns` shows *which combinations* of missing columns
actually occur, the same diagnostic produced by R's `mice::md.pattern()`.
Useful for reasoning about the missingness mechanism (e.g. if two columns
are always missing together, that's rarely MCAR) and for choosing an
imputation strategy. For a correlation-style view of the same question, see
[`missingcooccurrence`](@ref).

# Arguments
- `io::IO`: output stream (default: `stdout`).
- `tbl`: any Tables.jl-compatible table.
- `max_patterns::Int`: maximum number of patterns to display, most-frequent
  first (default: 20). Patterns beyond this are summarized in a trailing count.
- `cell_chars::Int`: number of repeated characters per cell (default: 5, max: 80).
- `char_missing::Char`: character for a missing column in a pattern (default: `'█'`).
- `char_present::Char`: character for a present column in a pattern (default: `'░'`).
- `name_width::Int`: max characters shown for column names before truncating with `…`
  (default: 4; set to 0 to show full names, bounded by cell width).
- `color_cells::Bool`: apply the same color ramp as `plotmissing` (default: `false`).
- `missing_color::String`: hex color of the ramp, as in `plotmissing`
  (default: `"#f3a9a9"`).
- `emphasis::Symbol`: `:present` (present columns colored, missing dark) or
  `:missing` (inverted), as in `plotmissing` (default: `:present`).
- `show_bar::Bool`: append an UpSet-style horizontal frequency bar per
  pattern, scaled to the most common displayed pattern (default: `true`).
- `min_pct::Float64`: hide patterns matching fewer than this percentage of
  rows (default: `0.0` — show all). Hidden patterns are reported in the
  trailing summary line.

# Returns
- `nothing`. The table is written to `io`.
"""
function missingpatterns(io::IO, tbl; max_patterns::Int=20,
                          cell_chars::Int=5, char_missing::Char='█', char_present::Char='░',
                          name_width::Int=4, color_cells::Bool=false,
                          missing_color::String="#f3a9a9", emphasis::Symbol=:present,
                          show_bar::Bool=true, min_pct::Float64=0.0)
    _validate_style_params(cell_chars, name_width)
    max_patterns > 0 || throw(ArgumentError("max_patterns must be positive, got $max_patterns"))
    emphasis in (:present, :missing) ||
        throw(ArgumentError("emphasis must be :present or :missing, got :$emphasis"))
    0.0 <= min_pct <= 100.0 ||
        throw(ArgumentError("min_pct must be within [0, 100], got $min_pct"))

    _, _, nrows, ncols = _table_info(tbl)
    if nrows == 0 || ncols == 0
        println(io, "Empty table — nothing to display")
        return nothing
    end

    stats = compute_pattern_stats(tbl)
    style = _make_render_style(io; cell_chars, char_missing, char_present, name_width,
                                color_cells, missing_color, emphasis)

    buf = IOBuffer()
    shown, nkept = render_pattern_table!(buf, stats, style, max_patterns;
                                          show_bar, min_pct)
    write(buf, '\n')

    npatterns = length(stats.counts)
    print(buf, " ", npatterns, " unique pattern", npatterns == 1 ? "" : "s",
          " across ", stats.nrows, " row", stats.nrows == 1 ? "" : "s")
    if nkept < npatterns
        print(buf, "  ┊ ", npatterns - nkept, " below min_pct=", min_pct, "% hidden")
    end
    if shown < nkept
        print(buf, "  ┊ showing top ", shown, " of ", nkept)
    end
    write(buf, '\n')

    write(io, take!(buf))
    return nothing
end

missingpatterns(tbl; kwargs...) = missingpatterns(stdout, tbl; kwargs...)

# =============================================================================
# STAGE 1c — Calculation (pure, no IO): temporal grouping
#
# `compute_missing_stats` groups rows *positionally* — correct only when the
# table happens to be sorted the way you want to read it. Grouping by the
# values of a Date/DateTime column instead makes the vertical axis honest
# calendar time: "2013 has a hole in RADI" rather than "rows 81k–85k do".
# =============================================================================

const _MISSING_GROUP_LABEL = "∅"

_period_key(::Missing, ::Val) = nothing
_period_key(x::Dates.TimeType, ::Val{:year})    = Int(Dates.year(x))
_period_key(x::Dates.TimeType, ::Val{:quarter}) = (Int(Dates.year(x)), Int(Dates.quarterofyear(x)))
_period_key(x::Dates.TimeType, ::Val{:month})   = (Int(Dates.year(x)), Int(Dates.month(x)))
_period_key(x::Dates.TimeType, ::Val{:week})    = (Int(Dates.year(x)), Int(Dates.week(x)))
_period_key(x::Dates.TimeType, ::Val{:day})     = Dates.Date(x)
_period_key(x, ::Val) = throw(ArgumentError(
    "`by` column must contain Date/DateTime values (or missing), got $(typeof(x))"))

_period_label(k::Integer, ::Val{:year})          = string(k)
_period_label(k::Tuple{Int,Int}, ::Val{:quarter}) = string(k[1], "-Q", k[2])
_period_label(k::Tuple{Int,Int}, ::Val{:month})   = @sprintf("%04d-%02d", k[1], k[2])
_period_label(k::Tuple{Int,Int}, ::Val{:week})    = @sprintf("%04d-W%02d", k[1], k[2])
_period_label(k::Dates.Date, ::Val{:day})         = string(k)
_period_label(::Nothing, ::Val)                   = _MISSING_GROUP_LABEL

# Function barrier: comprehension over the concrete-eltype column gives a
# tight Union-typed key vector without per-element dynamic dispatch.
@inline _row_period_keys(col::AbstractVector, pv::Val) = [_period_key(x, pv) for x in col]

"""
    _accumulate_column_grouped!(group_counts, col, gids) -> Int

Grouped sibling of `_accumulate_column!`: tallies missing values into
per-*group* buckets (group membership given by `gids`, one id per row)
instead of positional row blocks. Same function-barrier design — the inner
loop specializes on the column's concrete eltype.
"""
@inline function _accumulate_column_grouped!(group_counts::AbstractVector{Int},
                                              col::AbstractVector,
                                              gids::Vector{Int})
    total = 0
    @inbounds for i in eachindex(col)
        m = ismissing(col[i]) ? 1 : 0
        total += m
        group_counts[gids[i]] += m
    end
    return total
end

"""
    compute_missing_stats_grouped(tbl, by, period; max_rows, max_cols) -> MissingGridStats

Like [`compute_missing_stats`](@ref), but rows are grouped by the calendar
`period` of the `by` column's values instead of by position. Groups are
sorted chronologically; rows with a `missing` date form a trailing `∅`
group. When there are more periods than `max_rows`, *consecutive* periods
are merged into one block and labeled as a range (e.g. `2004-2005`), with
proportions weighted by each period's true row count — so unequal-sized
periods never distort the picture.
"""
function compute_missing_stats_grouped(tbl, by, period::Symbol;
                                        max_rows::Int, max_cols::Int)
    period in (:year, :quarter, :month, :week, :day) ||
        throw(ArgumentError("period must be :year, :quarter, :month, :week or :day, got :$period"))

    cols, src_colnames, nrows, ncols = _table_info(tbl)
    byname = String(by)
    bidx = findfirst(==(byname), src_colnames)
    bidx === nothing && throw(ArgumentError(
        "`by` column \"$byname\" not found; available: $(join(src_colnames, ", "))"))

    pv = Val(period)
    rowkeys = _row_period_keys(Tables.getcolumn(cols, bidx), pv)

    present_keys = sort!(unique(k for k in rowkeys if k !== nothing))
    ordered = Vector{Any}(present_keys)
    any(k -> k === nothing, rowkeys) && push!(ordered, nothing)
    ngroups = length(ordered)

    gid = Dict{Any,Int}(k => i for (i, k) in enumerate(ordered))
    gids = Vector{Int}(undef, nrows)
    @inbounds for i in 1:nrows
        gids[i] = gid[rowkeys[i]]
    end
    gsize = zeros(Int, ngroups)
    for g in gids
        gsize[g] += 1
    end

    cols_per_cell = ncols > max_cols ? cld(ncols, max_cols) : 1
    dc = cld(ncols, cols_per_cell)

    group_counts = zeros(Int, ngroups, dc)
    col_missing_total = zeros(Int, dc)
    for j in 1:ncols
        jc = div(j - 1, cols_per_cell) + 1
        col_missing_total[jc] += _accumulate_column_grouped!(view(group_counts, :, jc),
                                                              Tables.getcolumn(cols, j),
                                                              gids)
    end

    missing_count = sum(col_missing_total)
    total_cells = nrows * ncols

    groups_per_cell = ngroups > max_rows ? cld(ngroups, max_rows) : 1
    dr = cld(ngroups, groups_per_cell)

    proportions = Matrix{Float64}(undef, dr, dc)
    col_header_pct = Vector{Float64}(undef, dc)
    colnames = Vector{String}(undef, dc)
    row_lo = Vector{String}(undef, dr)
    row_hi = Vector{String}(undef, dr)
    row_labels = Vector{String}(undef, dr)

    for jc in 1:dc
        cs = (jc - 1) * cols_per_cell + 1
        ce = min(jc * cols_per_cell, ncols)
        col_header_pct[jc] = 100 * col_missing_total[jc] / (nrows * (ce - cs + 1))
        colnames[jc] = cs == ce ? src_colnames[cs] : string(cs, "-", ce)
    end

    for ir in 1:dr
        gs = (ir - 1) * groups_per_cell + 1
        ge = min(ir * groups_per_cell, ngroups)
        rows_in = 0
        @inbounds for g in gs:ge
            rows_in += gsize[g]
        end
        row_lo[ir] = _period_label(ordered[gs], pv)
        row_hi[ir] = _period_label(ordered[ge], pv)
        row_labels[ir] = row_lo[ir] == row_hi[ir] ? row_lo[ir] :
                         string(row_lo[ir], "-", row_hi[ir])
        for jc in 1:dc
            cs = (jc - 1) * cols_per_cell + 1
            ce = min(jc * cols_per_cell, ncols)
            cnt = 0
            @inbounds for g in gs:ge
                cnt += group_counts[g, jc]
            end
            block_size = rows_in * (ce - cs + 1)
            proportions[ir, jc] = block_size == 0 ? 0.0 : cnt / block_size
        end
    end

    needs_compression = groups_per_cell > 1 || cols_per_cell > 1
    group_desc = string("by ", byname, " (", period, ")")

    # rows_per_cell = 0 signals "rows are value-grouped, not positional".
    return MissingGridStats(nrows, ncols, dr, dc, 0, cols_per_cell,
                             needs_compression, proportions, col_header_pct,
                             colnames, row_labels, row_lo, row_hi, group_desc,
                             missing_count, total_cells)
end

# =============================================================================
# STAGE 1d — Calculation (pure, no IO): pairwise co-occurrence of missingness
# =============================================================================

"""
    compute_cooccurrence(tbl; method=:phi) -> (M, colnames, n_missing_per_col, nrows)

Pairwise association between the *missingness masks* of every pair of
columns — the correlation-style answer to the question `missingpatterns`
answers by enumeration: which columns go missing together?

Built on top of [`compute_pattern_stats`](@ref): since each unique pattern
already carries its row count, the pairwise tallies cost
`O(npatterns × k²)` (k = missing columns per pattern) instead of
`O(nrows × ncols²)` — for real data with few distinct patterns this is
essentially free.

Methods:
- `:phi` — Pearson's ϕ coefficient of the two binary masks, in `[-1, 1]`.
  Positive: the columns tend to be missing *together* (rarely MCAR!);
  negative: their missingness repels.
- `:jaccard` — `|A ∩ B| / |A ∪ B|` of the missing-row sets, in `[0, 1]`.

Degenerate pairs (a column with zero or all-missing rows) yield `NaN`.
"""
function compute_cooccurrence(tbl; method::Symbol=:phi)
    method in (:phi, :jaccard) ||
        throw(ArgumentError("method must be :phi or :jaccard, got :$method"))

    ps = compute_pattern_stats(tbl)
    n, nc = ps.nrows, ps.ncols

    n1 = zeros(Int, nc)
    n11 = zeros(Int, nc, nc)
    for p in eachindex(ps.counts)
        c = ps.counts[p]
        idxs = findall(@view ps.pattern_missing[p, :])
        for a in idxs
            n1[a] += c
            for b in idxs
                n11[a, b] += c
            end
        end
    end

    M = Matrix{Float64}(undef, nc, nc)
    for a in 1:nc, b in 1:nc
        if method === :phi
            na, nb, nab = n1[a], n1[b], n11[a, b]
            # float early: na*(n-na)*nb*(n-nb) overflows Int64 for n ~ 10^5
            denom = sqrt(float(na) * (n - na) * nb * (n - nb))
            M[a, b] = denom == 0 ? NaN :
                (float(nab) * (n - na - nb + nab) - float(na - nab) * (nb - nab)) / denom
        else
            u = n1[a] + n1[b] - n11[a, b]
            M[a, b] = u == 0 ? NaN : n11[a, b] / u
        end
    end

    return M, ps.colnames, n1, n
end

"""
    _colored_cell!(buf, content, cw, prefix, suffix)

Center-padded text cell like `_cell!`, but with an ANSI prefix/suffix
wrapping the content (padding stays uncolored so backgrounds don't bleed).
"""
function _colored_cell!(buf::IO, content::AbstractString, cw::Int,
                         prefix::String, suffix::String)
    n = length(content)
    if n > cw - 2
        content = first(content, cw - 2)
        n = cw - 2
    end
    pt = cw - n
    pl = div(pt, 2)
    _write_spaces!(buf, pl)
    isempty(prefix) || write(buf, prefix)
    write(buf, content)
    isempty(suffix) || write(buf, suffix)
    _write_spaces!(buf, pt - pl)
    return nothing
end

"""
    missingcooccurrence([io::IO=stdout], tbl; method=:phi, cell_chars=5,
                         name_width=4, color=:auto, missing_color="#f3a9a9",
                         max_cols=20)

Display the pairwise co-occurrence matrix of missingness between columns —
ϕ coefficient (default) or Jaccard index of the missing masks. High
positive values mean "these columns go missing together", which is strong
evidence against MCAR and directly informs imputation strategy.

If the table has more than `max_cols` columns, the `max_cols` columns with
the most missing values are shown (they carry the information) and a note
reports how many were omitted. Diagonal cells are `—`; degenerate pairs
(columns with no missing values) are `·`.

Cell text is the coefficient (`-1.00`…`1.00`); with color enabled, cell
intensity scales with `|value|` using `missing_color`.
"""
function missingcooccurrence(io::IO, tbl; method::Symbol=:phi, cell_chars::Int=5,
                              name_width::Int=4, color::Symbol=:auto,
                              missing_color::String="#f3a9a9", max_cols::Int=20)
    _validate_style_params(cell_chars, name_width)
    color in (:auto, :always, :never) ||
        throw(ArgumentError("color must be :auto, :always or :never, got :$color"))
    max_cols > 0 || throw(ArgumentError("max_cols must be positive, got $max_cols"))

    _, _, nrows, ncols = _table_info(tbl)
    if nrows == 0 || ncols == 0
        println(io, "Empty table — nothing to display")
        return nothing
    end

    M, colnames, n1, n = compute_cooccurrence(tbl; method)

    sel = collect(1:length(colnames))
    dropped = 0
    if length(sel) > max_cols
        sel = sortperm(n1; rev=true)[1:max_cols]
        sort!(sel)
        dropped = length(colnames) - max_cols
    end

    force_color = color === :auto ? nothing : (color === :always)
    style = _make_render_style(io; cell_chars, char_missing='█', char_present='░',
                                name_width, color_cells=true, force_color, missing_color)
    cw, hbar = style.cw, style.hbar
    dc = length(sel) + 1  # leading name column

    buf = IOBuffer()
    _hborder!(buf, dc, hbar, "", false, '┏', '┳', '┓')

    write(buf, '┃')
    _cell!(buf, method === :phi ? "ϕ" : "J", cw)
    write(buf, '┃')
    for j in sel
        _cell!(buf, _trunc_name(colnames[j], style.name_width), cw)
        write(buf, '┃')
    end
    write(buf, '\n')

    _hborder!(buf, dc, hbar, "", false, '┣', '╋', '┫')

    for a in sel
        write(buf, '┃')
        _cell!(buf, _trunc_name(colnames[a], style.name_width), cw)
        write(buf, '┃')
        for b in sel
            v = M[a, b]
            if a == b
                _cell!(buf, "—", cw)
            elseif isnan(v)
                _cell!(buf, "·", cw)
            else
                txt = @sprintf("%.2f", v)
                if style.use_color
                    t = clamp(abs(v), 0.0, 1.0)
                    rgb = _blend(_PRESENT_RGB, style.ramp.target, 0.15 + 0.85 * t)
                    _colored_cell!(buf, txt, cw, _fg_rgb(rgb), style.rst)
                else
                    _cell!(buf, txt, cw)
                end
            end
            write(buf, '┃')
        end
        write(buf, '\n')
    end

    _hborder!(buf, dc, hbar, "", false, '┗', '┻', '┛')

    print(buf, " pairwise ", method === :phi ? "ϕ" : "Jaccard",
          " of missingness masks ┊ n = ", n, " rows")
    dropped > 0 && print(buf, " ┊ ", dropped,
                          " column", dropped == 1 ? "" : "s",
                          " with fewest missing omitted")
    write(buf, '\n')

    write(io, take!(buf))
    return nothing
end

missingcooccurrence(tbl; kwargs...) = missingcooccurrence(stdout, tbl; kwargs...)

# =============================================================================
# STAGE 1e/2e — Per-column summary with sparklines
# =============================================================================

const _SPARK_CHARS = ('▁', '▂', '▃', '▄', '▅', '▆', '▇', '█')

"""
    missingsummary([io::IO=stdout], tbl; bins=20, sortby=:missing,
                    color=:auto, missing_color="#f3a9a9")

Per-column missing-data overview: name, element type, missing count, %,
and a sparkline showing *where along the rows* the missing values
concentrate — the row axis is split into `bins` equal blocks and each block
maps to a bar height proportional to its missing fraction. A block with
even one missing value renders at least the smallest bar (same visibility
guarantee as `plotmissing`); a block with none renders blank.

# Arguments
- `bins::Int`: sparkline resolution (default: 20).
- `sortby::Symbol`: `:missing` (descending missing count, default),
  `:name`, or `:none` (table order).
- `color::Symbol` / `missing_color::String`: as in [`plotmissing`](@ref);
  the sparkline colors bars by their missing fraction.
"""
function missingsummary(io::IO, tbl; bins::Int=20, sortby::Symbol=:missing,
                         color::Symbol=:auto, missing_color::String="#f3a9a9")
    bins > 0 || throw(ArgumentError("bins must be positive, got $bins"))
    sortby in (:missing, :name, :none) ||
        throw(ArgumentError("sortby must be :missing, :name or :none, got :$sortby"))
    color in (:auto, :always, :never) ||
        throw(ArgumentError("color must be :auto, :always or :never, got :$color"))

    cols, colnames, nrows, ncols = _table_info(tbl)
    if nrows == 0 || ncols == 0
        println(io, "Empty table — nothing to display")
        return nothing
    end

    binsize = max(cld(nrows, bins), 1)
    nb = cld(nrows, binsize)

    counts = zeros(Int, nb, ncols)
    totals = Vector{Int}(undef, ncols)
    types = Vector{String}(undef, ncols)
    for j in 1:ncols
        col = Tables.getcolumn(cols, j)
        totals[j] = _accumulate_column!(view(counts, :, j), col, binsize)
        types[j] = string(Base.nonmissingtype(eltype(col)))
    end

    order = sortby === :missing ? sortperm(totals; rev=true) :
            sortby === :name    ? sortperm(colnames) :
                                  collect(1:ncols)

    force_color = color === :auto ? nothing : (color === :always)
    use_color = force_color === nothing ? _use_color(io) : force_color
    ramp = ColorRamp(_PRESENT_RGB, _parse_hex(missing_color), :missing)
    rst = use_color ? "\033[0m" : ""

    nw = clamp(maximum(length, colnames), 6, 24)
    tw = clamp(maximum(length, types), 4, 12)

    _fit(s, w) = length(s) > w ? string(first(s, w - 1), '…') : s

    buf = IOBuffer()
    println(buf, ' ', rpad("column", nw), "  ", rpad("type", tw), "  ",
            lpad("missing", 9), "  ", lpad("%", 7), "  distribution")
    for j in order
        pct = 100 * totals[j] / nrows
        print(buf, ' ', rpad(_fit(colnames[j], nw), nw), "  ",
              rpad(_fit(types[j], tw), tw), "  ",
              lpad(string(totals[j]), 9), "  ",
              lpad(@sprintf("%.2f%%", pct), 7), "  ")
        for b in 1:nb
            bsz = min(binsize, nrows - (b - 1) * binsize)
            p = counts[b, j] / bsz
            if p <= 0.0
                write(buf, ' ')
            else
                lvl = clamp(ceil(Int, p * 8), 1, 8)
                use_color && write(buf, _fg_rgb(_ramp_rgb(ramp, p)))
                write(buf, _SPARK_CHARS[lvl])
                use_color && write(buf, rst)
            end
        end
        write(buf, '\n')
    end
    tm = sum(totals)
    println(buf, ' ', tm, " missing of ", nrows * ncols, " cells (",
            @sprintf("%.2f", 100 * tm / (nrows * ncols)), "%) across ",
            ncols, " columns ┊ bins of ", binsize, " row",
            binsize == 1 ? "" : "s")

    write(io, take!(buf))
    return nothing
end

missingsummary(tbl; kwargs...) = missingsummary(stdout, tbl; kwargs...)

# =============================================================================
# STAGE 2f — Before/after diff (auditing imputation or dataset updates)
# =============================================================================

"""
    _diff_counts(before_col, after_col) -> (resolved, introduced)

Row-aligned pass over one column of both tables: `resolved` counts cells
missing before but present after (e.g. imputed), `introduced` the reverse.
Same function-barrier pattern as every other hot loop in the package.
"""
@inline function _diff_counts(b::AbstractVector, a::AbstractVector)
    resolved = 0
    introduced = 0
    @inbounds for i in eachindex(b)
        mb = ismissing(b[i])
        ma = ismissing(a[i])
        resolved   += (mb && !ma) ? 1 : 0
        introduced += (!mb && ma) ? 1 : 0
    end
    return resolved, introduced
end

"""
    _diff_rgb(delta, worse, better) -> NTuple{3,Int}

Signed variant of `_ramp_rgb`: zero delta is neutral dark gray; positive
deltas (more missing after) blend toward `worse`, negative (holes filled)
toward `better` — with the same ~30% + √ visibility floor, so even a
single changed cell inside a huge block produces a visible tint.
"""
function _diff_rgb(d::Float64, worse::NTuple{3,Int}, better::NTuple{3,Int})
    d == 0.0 && return _PRESENT_RGB
    t = 0.30 + 0.70 * sqrt(clamp(abs(d), 0.0, 1.0))
    return d > 0 ? _blend(_PRESENT_RGB, worse, t) : _blend(_PRESENT_RGB, better, t)
end

"""
    plotmissingdiff([io::IO=stdout], before, after; cell_chars=5, name_width=4,
                     max_cols=20, target_lines=28, color=:auto,
                     missing_color="#f3a9a9", filled_color="#a9f3c1")

Compare the missingness of two same-shaped tables — typically the same
dataset before and after an imputation step, or two releases of a periodic
microdata file. Rendered in the compact layout (fits `target_lines`):

- neutral dark gray — block unchanged;
- tint of `missing_color` — block got *more* missing (introduced holes);
- tint of `filled_color` — block got *less* missing (holes resolved).

With color, half-blocks encode two row blocks per line (as in
`plotmissing`); without color, cells fall back to `+` (more missing),
`-` (fewer) and `·` (unchanged) glyphs. The summary line reports exact
cell-level counts of resolved and introduced missing values, computed by a
row-aligned pass (not from block averages).

Both tables must have identical dimensions and column names, in order.
"""
function plotmissingdiff(io::IO, before, after; cell_chars::Int=5, name_width::Int=4,
                          max_cols::Int=20, target_lines::Int=28, color::Symbol=:auto,
                          missing_color::String="#f3a9a9",
                          filled_color::String="#a9f3c1")
    _validate_style_params(cell_chars, name_width)
    color in (:auto, :always, :never) ||
        throw(ArgumentError("color must be :auto, :always or :never, got :$color"))
    target_lines >= _COMPACT_OVERHEAD + 1 ||
        throw(ArgumentError("target_lines must be at least $(_COMPACT_OVERHEAD + 1), got $target_lines"))

    cb, names_b, nrb, ncb = _table_info(before)
    ca, names_a, nra, nca = _table_info(after)
    (nrb == nra && ncb == nca) || throw(ArgumentError(
        "before ($nrb×$ncb) and after ($nra×$nca) must have identical dimensions"))
    names_b == names_a || throw(ArgumentError(
        "before/after must have the same column names in the same order"))
    if nrb == 0 || ncb == 0
        println(io, "Empty table — nothing to display")
        return nothing
    end

    force_color = color === :auto ? nothing : (color === :always)
    use_color = force_color === nothing ? _use_color(io) : force_color
    halfblock = use_color

    eff_max_rows = _compact_max_rows(target_lines, halfblock)
    sb = compute_missing_stats(before; max_rows=eff_max_rows, max_cols)
    sa = compute_missing_stats(after;  max_rows=eff_max_rows, max_cols)
    delta = sa.proportions .- sb.proportions

    worse  = _parse_hex(missing_color)
    better = _parse_hex(filled_color)

    resolved = 0
    introduced = 0
    for j in 1:ncb
        r, i = _diff_counts(Tables.getcolumn(cb, j), Tables.getcolumn(ca, j))
        resolved += r
        introduced += i
    end

    cw = max(cell_chars + 2, 9)
    hbar = repeat("━", cw)
    rst = use_color ? "\033[0m" : ""
    dr, dc = sb.dr, sb.dc

    buf = IOBuffer()
    _hborder!(buf, dc, hbar, "", false, '┏', '┳', '┓')

    write(buf, '┃')
    for j in 1:dc
        dpct = sa.col_header_pct[j] - sb.col_header_pct[j]
        _cell!(buf, _compact_header_text(sb.colnames[j],
                                          @sprintf("%+d%%", round(Int, dpct)),
                                          cw, name_width), cw)
        write(buf, '┃')
    end
    write(buf, '\n')

    _hborder!(buf, dc, hbar, "", false, '┣', '╋', '┫')

    if halfblock
        i = 1
        while i <= dr
            bot = i + 1 <= dr ? i + 1 : 0
            write(buf, '┃')
            for j in 1:dc
                fgc = _diff_rgb(delta[i, j], worse, better)
                bgc = bot == 0 ? nothing : _diff_rgb(delta[bot, j], worse, better)
                _halfblock_cell!(buf, fgc, bgc, cell_chars, cw, rst)
                write(buf, '┃')
            end
            write(buf, '\n')
            i += 2
        end
    else
        for i in 1:dr
            write(buf, '┃')
            for j in 1:dc
                d = delta[i, j]
                glyph = d == 0.0 ? '·' : d > 0 ? '+' : '-'
                _data_cell!(buf, glyph, cell_chars, cw, "", "")
                write(buf, '┃')
            end
            write(buf, '\n')
        end
    end

    _hborder!(buf, dc, hbar, "", false, '┗', '┻', '┛')

    pct_b = 100 * sb.missing_count / sb.total_cells
    pct_a = 100 * sa.missing_count / sa.total_cells
    print(buf, " Δ missing: ", @sprintf("%.2f%%", pct_b), " → ",
          @sprintf("%.2f%%", pct_a),
          " ┊ resolved ", resolved, " ┊ introduced ", introduced)
    write(buf, '\n')

    write(io, take!(buf))
    return nothing
end

plotmissingdiff(before, after; kwargs...) = plotmissingdiff(stdout, before, after; kwargs...)

# =============================================================================
# STAGE 2g — HTML export
# =============================================================================

# Multi-pair `replace` needs Julia 1.7; chain single pairs to honor the 1.6 floor.
function _html_escape(s::AbstractString)
    t = replace(s, '&' => "&amp;")
    t = replace(t, '<' => "&lt;")
    t = replace(t, '>' => "&gt;")
    return replace(t, '"' => "&quot;")
end

_css_rgb(c::NTuple{3,Int}) = string("rgb(", c[1], ",", c[2], ",", c[3], ")")

"""
    missinghtml(tbl; max_rows=200, max_cols=60, missing_color="#f3a9a9",
                emphasis=:present, title="Missing data") -> String
    missinghtml(path::AbstractString, tbl; kwargs...) -> path

Render the missing-data heatmap as a standalone HTML fragment (dark-themed
`<div>`, no external CSS/JS) — suitable for pasting into a blog post,
notebook export, or report. Column headers are rotated for readability;
every cell carries a tooltip with its row range and exact missing
percentage. The same compression engine and color ramp as
[`plotmissing`](@ref) are used, so the two outputs always agree — HTML just
affords a much larger grid (defaults: 200×60 blocks).

The one-argument form returns the HTML `String`; the two-argument form
writes it to `path` and returns the path.
"""
function missinghtml(tbl; max_rows::Int=200, max_cols::Int=60,
                      missing_color::String="#f3a9a9", emphasis::Symbol=:present,
                      title::AbstractString="Missing data")
    _validate_display_params(max_rows, max_cols)
    emphasis in (:present, :missing) ||
        throw(ArgumentError("emphasis must be :present or :missing, got :$emphasis"))

    _, _, nrows, ncols = _table_info(tbl)
    if nrows == 0 || ncols == 0
        return "<div style=\"font-family:monospace\">Empty table — nothing to display</div>"
    end

    stats = compute_missing_stats(tbl; max_rows, max_cols)
    ramp = ColorRamp(_PRESENT_RGB, _parse_hex(missing_color), emphasis)
    missing_pct = 100 * stats.missing_count / stats.total_cells

    io = IOBuffer()
    print(io, "<div style=\"background:#1e1f29;color:#d8d8de;",
          "font-family:ui-monospace,monospace;font-size:12px;",
          "padding:16px;border-radius:8px;display:inline-block\">")
    print(io, "<div style=\"margin-bottom:8px;font-weight:bold\">",
          _html_escape(title), "</div>")

    print(io, "<div style=\"display:grid;grid-template-columns:repeat(",
          stats.dc, ",14px);gap:1px;align-items:end\">")
    for j in 1:stats.dc
        pct = round(Int, stats.col_header_pct[j])
        print(io, "<div style=\"writing-mode:vertical-rl;transform:rotate(180deg);",
              "font-size:10px;color:#9a9aa6;padding-bottom:4px\" title=\"",
              _html_escape(stats.colnames[j]), ": ", pct, "% missing\">",
              _html_escape(stats.colnames[j]), " ", pct, "%</div>")
    end
    for i in 1:stats.dr, j in 1:stats.dc
        p = stats.proportions[i, j]
        tip = string(_html_escape(stats.colnames[j]), " · rows ",
                     stats.row_labels[i], " · ",
                     @sprintf("%.2f", 100p), "% missing")
        print(io, "<div style=\"width:14px;height:8px;background:",
              _css_rgb(_ramp_rgb(ramp, p)), "\" title=\"", tip, "\"></div>")
    end
    print(io, "</div>")

    print(io, "<div style=\"margin-top:8px;color:#9a9aa6\">",
          stats.nrows, "×", stats.ncols, " → ", stats.dr, "×", stats.dc,
          " blocks ┊ missing ", @sprintf("%.2f", missing_pct), "% (",
          stats.missing_count, ")</div>")
    print(io, "</div>")

    return String(take!(io))
end

function missinghtml(path::AbstractString, tbl; kwargs...)
    open(path, "w") do f
        write(f, missinghtml(tbl; kwargs...))
    end
    return path
end

# =============================================================================
# Precompile workload — makes the first `plotmissing` call in a fresh REPL
# effectively instant when the package is properly installed. Skipped
# gracefully (via runtime `@eval`) when PrecompileTools isn't available,
# e.g. when this file is `include()`d directly outside a Pkg environment.
# =============================================================================

const _HAS_PRECOMPILETOOLS = try
    @eval import PrecompileTools
    true
catch
    false
end

if _HAS_PRECOMPILETOOLS
    @eval PrecompileTools.@compile_workload begin
        _tbl = (a = [1, missing, 3, 4],
                b = [missing, missing, 1.0, 2.0],
                c = ["x", "y", missing, "z"],
                d = [Dates.Date(2024, 1, 1), Dates.Date(2024, 2, 1),
                     missing, Dates.Date(2025, 1, 1)])
        _io = IOContext(devnull, :color => true)
        plotmissing(_io, _tbl)
        plotmissing(_io, _tbl; layout=:compact, color=:always)
        plotmissing(_io, _tbl; by=:d, period=:year)
        missingpatterns(_io, _tbl)
        missingsummary(_io, _tbl)
        missingcooccurrence(_io, _tbl)
        plotmissingdiff(_io, _tbl, _tbl)
        missinghtml(_tbl)
    end
end

end
