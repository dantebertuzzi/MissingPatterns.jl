"""
    MissingPatterns

A terminal-based text heatmap for visualizing missing data patterns in DataFrames,
with zero plotting-library dependencies.

Only `plotmissing` is exported. See its docstring for usage.
"""
module MissingPatterns

using Printf
using Statistics
using DataFrames

export plotmissing

function _validate_params(cell_chars, name_width, max_rows, max_cols)
    cell_chars > 0  || throw(ArgumentError("cell_chars must be positive, got $cell_chars"))
    cell_chars <= 80 || throw(ArgumentError("cell_chars too large (max 80), got $cell_chars"))
    name_width >= 0  || throw(ArgumentError("name_width must be >= 0, got $name_width"))
    max_rows > 0   || throw(ArgumentError("max_rows must be positive, got $max_rows"))
    max_cols > 0   || throw(ArgumentError("max_cols must be positive, got $max_cols"))
    nothing
end

function _use_color(io::IO)
    isa(io, Base.TTY) && return true
    get(io, :color, false) == true && return true
    return false
end

function _compress_data(data::Matrix{Bool}, target_rows::Int, target_cols::Int)
    orig_rows, orig_cols = size(data)
    rows_per_cell = ceil(Int, orig_rows / target_rows)
    cols_per_cell = ceil(Int, orig_cols / target_cols)

    cr = ceil(Int, orig_rows / rows_per_cell)
    cc = ceil(Int, orig_cols / cols_per_cell)

    compressed = Matrix{Float64}(undef, cr, cc)

    for i in 1:cr
        rs = (i - 1) * rows_per_cell + 1
        re = min(i * rows_per_cell, orig_rows)
        for j in 1:cc
            cs = (j - 1) * cols_per_cell + 1
            ce = min(j * cols_per_cell, orig_cols)
            block = data[rs:re, cs:ce]
            compressed[i, j] = sum(block) / length(block)
        end
    end

    return compressed, rows_per_cell, cols_per_cell
end

function _prop_to_char(prop::Float64)
    prop <= 0.05 && return '·'
    prop <= 0.15 && return '░'
    prop <= 0.30 && return '▒'
    prop <= 0.50 && return '▓'
    return '█'
end

function _cell_color(prop::Float64)
    prop == 0.0 && return ""
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

"""
    plotmissing([io::IO=stdout], df; cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false, max_rows=50, max_cols=20)

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
- `max_rows::Int`: maximum display rows before compression (default: 50).
- `max_cols::Int`: maximum display columns before compression (default: 20).

# Returns
- `nothing`. The plot is written to `io`.
"""
function plotmissing(io::IO, df::AbstractDataFrame; cell_chars::Int=5,
                     char_missing::Char='█', char_present::Char='░',
                     name_width::Int=4, color_cells::Bool=false,
                     max_rows::Int=50, max_cols::Int=20,
                     char_width::Int=-1)

    if char_width != -1
        Base.depwarn(
            "keyword argument `char_width` is deprecated, use `cell_chars` instead.",
            :plotmissing
        )
        cell_chars = char_width
    end

    _validate_params(cell_chars, name_width, max_rows, max_cols)

    nrows, ncols = size(df)
    if nrows == 0 || ncols == 0
        println(io, "Empty DataFrame — nothing to display")
        return nothing
    end

    missing_values = Matrix{Bool}(ismissing.(df))
    colnames = string.(names(df))

    needs_compression = nrows > max_rows || ncols > max_cols

    if needs_compression
        tr = min(nrows, max_rows)
        tc = min(ncols, max_cols)
        compressed_data, rpc, cpc = _compress_data(missing_values, tr, tc)
        dr, dc = size(compressed_data)

        compressed_colnames = Vector{String}(undef, dc)
        for j in 1:dc
            cs = (j - 1) * cpc + 1
            ce = min(j * cpc, ncols)
            compressed_colnames[j] = cs == ce ? colnames[cs] : "$(cs)-$(ce)"
        end
        rows_per_cell, cols_per_cell = rpc, cpc
    else
        compressed_data = Float64.(missing_values)
        dr, dc = nrows, ncols
        compressed_colnames = colnames
        rows_per_cell = cols_per_cell = 1
    end

    buf = IOBuffer()
    cw = max(cell_chars + 2, 9)
    hbar = repeat("━", cw)
    c_missing = string(char_missing)
    c_present = string(char_present)

    use_color = _use_color(io)
    rst    = use_color ? "\033[0m" : ""
    blue   = use_color ? "\033[34m" : ""
    orange = use_color ? "\033[38;5;208m" : ""

    function _hborder(left::Char, sep::Char, right::Char)
        print(buf, left)
        for k in 1:dc
            k > 1 && print(buf, sep)
            print(buf, hbar)
        end
        println(buf, right)
    end

    function _cell(content::AbstractString, prefix::AbstractString="", suffix::AbstractString="")
        n = length(content)
        if n > cw - 2
            content = first(content, cw - 2)
            n = cw - 2
        end
        pt = cw - n
        pl = div(pt, 2)
        print(buf, repeat(" ", pl), prefix, content, suffix, repeat(" ", pt - pl))
    end

    _hborder('┏', '┳', '┓')

    print(buf, '┃')
    for j in 1:dc
        if needs_compression
            cs = (j - 1) * cols_per_cell + 1
            ce = min(j * cols_per_cell, ncols)
            perc = 100 * sum(missing_values[:, cs:ce]) / (nrows * (ce - cs + 1))
        else
            perc = 100 * sum(compressed_data[:, j]) / nrows
        end
        _cell(@sprintf("%3d%%", round(Int, perc)))
        print(buf, '┃')
    end
    println(buf)

    _hborder('┣', '╋', '┫')

    print(buf, '┃')
    for j in 1:dc
        disp = _trunc_name(compressed_colnames[j], name_width)
        _cell(disp)
        print(buf, '┃')
    end
    println(buf)

    _hborder('┣', '╋', '┫')

    cell_color_on = color_cells && use_color

    for i in 1:dr
        print(buf, '┃')
        for j in 1:dc
            if needs_compression
                prop = compressed_data[i, j]
                if prop == 0.0
                    cellchar = repeat(c_present, cell_chars)
                elseif prop == 1.0
                    cellchar = repeat(c_missing, cell_chars)
                else
                    cellchar = repeat(string(_prop_to_char(prop)), cell_chars)
                end
                prefix = cell_color_on ? _cell_color(prop) : ""
                suffix = cell_color_on && prefix != "" ? rst : ""
            else
                is_missing = compressed_data[i, j] == 1.0
                cellchar = repeat(is_missing ? c_missing : c_present, cell_chars)
                if cell_color_on
                    prefix = is_missing ? "\033[31m" : ""
                    suffix = is_missing ? rst : ""
                else
                    prefix = ""
                    suffix = ""
                end
            end
            _cell(cellchar, prefix, suffix)
            print(buf, '┃')
        end
        println(buf)
    end

    _hborder('┗', '┻', '┛')

    missing_count = sum(missing_values)
    total_cells = nrows * ncols
    present_count = total_cells - missing_count
    missing_pct = 100 * missing_count / total_cells
    present_pct = 100 - missing_pct

    println(buf)
    println(buf, "MissingPatterns.Analysis: ", blue, nrows, rst, " × ", blue, ncols, rst, " DataFrame")

    if needs_compression
        println(buf, " Compression: ", blue, nrows, rst, "×", blue, ncols, rst,
                " → ", blue, dr, rst, "×", blue, dc, rst,
                " cells  ┊ Ratio: ", blue, rows_per_cell, rst, "×", blue, cols_per_cell, rst, " per cell")
    else
        println(buf, " Compression: No compression needed                    ┊ Ratio: ",
                blue, "1", rst, "×", blue, "1", rst, " per cell")
    end

    mc_str = lpad(string(missing_count), 14)
    pc_str = lpad(string(present_count), 14)
    mp_str = lpad(@sprintf("%.2f", missing_pct), 13)
    pp_str = lpad(@sprintf("%.2f", present_pct), 13)

    println(buf, " Missing (count):  ", blue, mc_str, rst,
            "               ┊ Missing (", orange, '%', rst, "):  ",
            blue, mp_str, rst, orange, '%', rst)
    println(buf, " Present (count):  ", blue, pc_str, rst,
            "               ┊ Present (", orange, '%', rst, "):  ",
            blue, pp_str, rst, orange, '%', rst)

    tw = try
        displaysize(io)[2]
    catch
        80
    end
    bw = clamp(tw - 22, 20, 120)
    mb = round(Int, bw * missing_pct / 100)
    pb = bw - mb
    print(buf, " Progress Bar:     ", blue, '[', rst)
    mb > 0 && print(buf, orange, repeat("█", mb), rst)
    pb > 0 && print(buf, blue, repeat("█", pb), rst)
    println(buf, blue, ']', rst)

    print(io, String(take!(buf)))
    return nothing
end

plotmissing(df::AbstractDataFrame; kwargs...) = plotmissing(stdout, df; kwargs...)

end
