using Test
using Dates
using DataFrames
using MissingPatterns
using MissingPatterns: _parse_hex, _ramp_rgb, _blend, ColorRamp, _PRESENT_RGB,
                        _diff_counts, _diff_rgb, compute_missing_stats,
                        compute_missing_stats_grouped, compute_pattern_stats,
                        compute_cooccurrence, _compact_max_rows, _COMPACT_OVERHEAD,
                        _pair_row_label, _table_info, _use_color, _cell_glyph,
                        _bar_cell!, _compact_header_text, _make_render_style,
                        render_grid!, render_summary!, render_grid_compact!,
                        render_summary_compact!, render_pattern_table!,
                        _prop_to_char

const ANSI_RE = r"\e\[[0-9;]*m"
strip_ansi(s) = replace(s, ANSI_RE => "")

"Render `f(io, tbl; kwargs...)` into a String."
function rendered(f, args...; kwargs...)
    buf = IOBuffer()
    f(buf, args...; kwargs...)
    return String(take!(buf))
end

"Synthetic wide/tall table (Tables.jl-compatible NamedTuple of vectors)."
function bigtable(nrows=10_000, ncols=25; miss_every=17)
    make(j) = [i % (miss_every + j) == 0 ? missing : Float64(i) for i in 1:nrows]
    return NamedTuple{Tuple(Symbol("c$j") for j in 1:ncols)}(Tuple(make(j) for j in 1:ncols))
end

@testset "MissingPatterns" begin

    # =========================================================================
    # Tables.jl interface
    # =========================================================================
    @testset "Tables.jl interface" begin
        tbl = (a = [1, missing, 3], b = ["x", "y", missing])
        out = rendered(plotmissing, tbl; color=:never)
        @test occursin("MissingPatterns.Analysis", out)
        @test occursin('┏', out)
        @test occursin('┛', out)

        df = DataFrame(a = [1, missing, 3], b = ["x", "y", missing])
        out_df = rendered(plotmissing, df; color=:never)
        @test occursin("MissingPatterns.Analysis", out_df)

        @test_throws ArgumentError plotmissing(IOBuffer(), 42)
        @test occursin("Empty table", rendered(plotmissing, (;)))

        cols, names_, nr, nc = _table_info(tbl)
        @test nr == 3 && nc == 2
        @test names_ == ["a", "b"]
    end

    # =========================================================================
    # _use_color
    # =========================================================================
    @testset "_use_color" begin
        io = IOBuffer()
        @test !_use_color(io)
        @test _use_color(IOContext(io, :color => true))
        @test !_use_color(IOContext(io, :color => false))
    end

    # =========================================================================
    # _cell_glyph
    # =========================================================================
    @testset "_cell_glyph" begin
        @test _cell_glyph(0.0, 'X', '.') == '.'
        @test _cell_glyph(1.0, 'X', '.') == 'X'
        @test _cell_glyph(-0.5, 'X', '.') == '.'
        @test _cell_glyph(2.0, 'X', '.') == 'X'
        @test _cell_glyph(0.10, '█', '░') == '░'
        @test _cell_glyph(0.25, '█', '░') == '▒'
        @test _cell_glyph(0.45, '█', '░') == '▓'
        @test _cell_glyph(0.60, '█', '░') == '█'
    end

    # =========================================================================
    # _prop_to_char
    # =========================================================================
    @testset "_prop_to_char" begin
        @test _prop_to_char(0.00) == '·'
        @test _prop_to_char(0.05) == '·'
        @test _prop_to_char(0.06) == '░'
        @test _prop_to_char(0.15) == '░'
        @test _prop_to_char(0.16) == '▒'
        @test _prop_to_char(0.30) == '▒'
        @test _prop_to_char(0.31) == '▓'
        @test _prop_to_char(0.50) == '▓'
        @test _prop_to_char(0.51) == '█'
    end

    # =========================================================================
    # _bar_cell!
    # =========================================================================
    @testset "_bar_cell!" begin
        buf = IOBuffer()
        _bar_cell!(buf, 0.5, 12, "", "")
        out = String(take!(buf))
        @test length(out) == 12
        @test count(==('█'), out) == 5  # interior=10, ratio=0.5 → 5
        @test out[1] == ' ' && out[end] == ' '

        buf2 = IOBuffer()
        _bar_cell!(buf2, 1.0, 9, "", "")
        out2 = String(take!(buf2))
        @test count(==('█'), out2) == 7   # interior=7, ratio=1.0 → 7

        buf3 = IOBuffer()
        _bar_cell!(buf3, 0.0, 12, "", "")
        out3 = String(take!(buf3))
        @test count(==('█'), out3) == 0

        buf4 = IOBuffer()
        _bar_cell!(buf4, 1.0, 12, "\033[31m", "\033[0m")
        out4 = String(take!(buf4))
        @test occursin("\033[31m", out4)
        @test occursin("\033[0m", out4)
    end

    # =========================================================================
    # compute_missing_stats
    # =========================================================================
    @testset "compute_missing_stats" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6])
        stats = compute_missing_stats(tbl; max_rows=50, max_cols=20)

        @test stats.nrows == 3 && stats.ncols == 2
        @test stats.dr == 3 && stats.dc == 2
        @test !stats.needs_compression
        @test stats.rows_per_cell == 1 && stats.cols_per_cell == 1
        @test stats.missing_count == 2
        @test stats.total_cells == 6
        @test stats.proportions[1, 1] == 0.0
        @test stats.proportions[2, 1] == 1.0
        @test stats.proportions[1, 2] == 1.0
        @test stats.proportions[2, 2] == 0.0
        @test stats.row_labels == ["1", "2", "3"]
        @test stats.row_lo == ["1", "2", "3"]
        @test stats.row_hi == ["1", "2", "3"]
        @test isempty(stats.group_desc)

        @test isapprox(stats.col_header_pct[1], 100/3; atol=0.01)
        @test isapprox(stats.col_header_pct[2], 100/3; atol=0.01)

        # compression
        stats2 = compute_missing_stats(bigtable(100, 5); max_rows=20, max_cols=20)
        @test stats2.needs_compression
        @test stats2.dr <= 20
        @test stats2.rows_per_cell > 1
        @test all(x -> 0.0 <= x <= 1.0, stats2.proportions)
        @test all(x -> 0.0 <= x <= 100.0, stats2.col_header_pct)
        @test occursin('-', stats2.row_labels[end])

        # column compression
        n = 5
        tbl3 = bigtable(n, 30; miss_every=3)
        stats3 = compute_missing_stats(tbl3; max_rows=50, max_cols=10)
        @test stats3.needs_compression
        @test stats3.dr == n && stats3.dc <= 10
        @test stats3.cols_per_cell > 1
        @test occursin('-', stats3.colnames[2])
    end

    # =========================================================================
    # compute_pattern_stats
    # =========================================================================
    @testset "compute_pattern_stats" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6])
        ps = compute_pattern_stats(tbl)
        @test ps.nrows == 3 && ps.ncols == 2
        @test sum(ps.counts) == 3
        @test issorted(ps.counts; rev=true)
        @test size(ps.pattern_missing) == (length(ps.counts), 2)
        @test ps.colnames == ["A", "B"]

        # no missing → single pattern, all false
        tbl2 = (A = [1, 2, 3], B = [4, 5, 6])
        ps2 = compute_pattern_stats(tbl2)
        @test length(ps2.counts) == 1
        @test ps2.counts[1] == 3
        @test !any(ps2.pattern_missing)

        # all missing → single pattern, all true
        tbl3 = (A = [missing, missing], B = [missing, missing])
        ps3 = compute_pattern_stats(tbl3)
        @test length(ps3.counts) == 1
        @test all(ps3.pattern_missing)

        # wide (>64 cols) fallback
        wide = bigtable(30, 70)
        ps4 = compute_pattern_stats(wide)
        @test sum(ps4.counts) == 30
        @test size(ps4.pattern_missing, 2) == 70
    end

    # =========================================================================
    # _parse_hex
    # =========================================================================
    @testset "_parse_hex" begin
        @test _parse_hex("#f3a9a9") == (243, 169, 169)
        @test _parse_hex("f3a9a9") == (243, 169, 169)
        @test _parse_hex("AABBCC") == (170, 187, 204)
        @test _parse_hex("#000000") == (0, 0, 0)
        @test _parse_hex("#ffffff") == (255, 255, 255)
        @test _parse_hex("#FF00FF") == (255, 0, 255)
        @test_throws ArgumentError _parse_hex("#f3a9")
        @test_throws ArgumentError _parse_hex("f3a9a")
        @test_throws ArgumentError _parse_hex("nothex")
        @test_throws ArgumentError _parse_hex("")
    end

    # =========================================================================
    # ColorRamp, _ramp_rgb, _glyph_prefix
    # =========================================================================
    @testset "color ramp & micro-hole visibility" begin
        present = ColorRamp(_PRESENT_RGB, _parse_hex("#f3a9a9"), :present)
        @test _ramp_rgb(present, 0.0) == (243, 169, 169)
        @test _ramp_rgb(present, 1.0) == _PRESENT_RGB
        tiny = _ramp_rgb(present, 1 / 4167)
        @test tiny != _ramp_rgb(present, 0.0)
        @test sum(abs.(tiny .- (243, 169, 169))) > 30

        inverted = ColorRamp(_PRESENT_RGB, _parse_hex("#f3a9a9"), :missing)
        @test _ramp_rgb(inverted, 0.0) == _PRESENT_RGB
        @test _ramp_rgb(inverted, 1.0) == (243, 169, 169)
        @test _ramp_rgb(inverted, 1 / 4167) != _PRESENT_RGB

        @test _blend((0, 0, 0), (100, 100, 100), 0.0) == (0, 0, 0)
        @test _blend((0, 0, 0), (100, 100, 100), 1.0) == (100, 100, 100)
        @test _blend((0, 0, 0), (100, 100, 100), 0.5) == (50, 50, 50)
    end

    # =========================================================================
    # _make_render_style
    # =========================================================================
    @testset "_make_render_style" begin
        io = IOBuffer()
        style = _make_render_style(io; cell_chars=5, char_missing='█', char_present='░',
                                     name_width=4, color_cells=false)
        @test style.cell_chars == 5
        @test !style.use_color
        @test !style.show_row_range
        @test style.cw >= 7

        style_f = _make_render_style(io; cell_chars=5, char_missing='█', char_present='░',
                                       name_width=4, color_cells=true, force_color=true)
        @test style_f.use_color
        @test !isempty(style_f.rst)

        labels = ["1", "10-20"]
        style_r = _make_render_style(io; cell_chars=5, char_missing='█', char_present='░',
                                       name_width=4, color_cells=false, show_row_range=true,
                                       row_labels=labels)
        @test style_r.show_row_range
        @test style_r.rw >= 5
        @test !isempty(style_r.row_bar)

        style_c = _make_render_style(io; cell_chars=5, char_missing='█', char_present='░',
                                       name_width=4, color_cells=false, force_color=true,
                                       missing_color="#ff0000")
        @test style_c.ramp.target == (255, 0, 0)
    end

    # =========================================================================
    # render_grid! and render_summary!
    # =========================================================================
    @testset "render_grid! and render_summary!" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6])
        stats = compute_missing_stats(tbl; max_rows=50, max_cols=20)
        style = _make_render_style(IOBuffer(); cell_chars=5, char_missing='█',
                                     char_present='░', name_width=4, color_cells=false)

        buf = IOBuffer()
        render_grid!(buf, stats, style)
        out = String(take!(buf))
        @test occursin('┏', out) && occursin('┛', out)
        @test occursin('%', out) && occursin("A", out) && occursin("B", out)

        buf_s = IOBuffer()
        render_summary!(buf_s, stats, style, stdout)
        summary = String(take!(buf_s))
        @test occursin("MissingPatterns.Analysis:", summary)
        @test occursin("Missing (count):", summary)
        @test occursin("Present (count):", summary)
        @test occursin("Progress Bar:", summary)
        @test occursin("No compression needed", summary)
    end

    # =========================================================================
    # render_pattern_table!
    # =========================================================================
    @testset "render_pattern_table!" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6])
        ps = compute_pattern_stats(tbl)
        style = _make_render_style(IOBuffer(); cell_chars=5, char_missing='█',
                                     char_present='░', name_width=4, color_cells=false)

        buf = IOBuffer()
        shown, nkept = render_pattern_table!(buf, ps, style, 20)
        @test shown == length(ps.counts)
        @test nkept == length(ps.counts)
        out = String(take!(buf))
        @test occursin('┏', out) && occursin('┛', out)
        @test occursin("n", out) && occursin("%", out)
        @test occursin("freq", out)
        @test occursin('█', out)

        # show_bar=false
        buf2 = IOBuffer()
        render_pattern_table!(buf2, ps, style, 20; show_bar=false)
        out2 = String(take!(buf2))
        @test !occursin("freq", out2)

        # min_pct filter
        buf3 = IOBuffer()
        shown3, nkept3 = render_pattern_table!(buf3, ps, style, 20; min_pct=50.0)
        out3 = String(take!(buf3))
        @test nkept3 < length(ps.counts)
        @test shown3 == nkept3
    end

    # =========================================================================
    # _compact_header_text, _compact_max_rows, _pair_row_label
    # =========================================================================
    @testset "compact helpers" begin
        @test _compact_max_rows(28, true) == 46
        @test _compact_max_rows(28, false) == 23
        @test _compact_max_rows(10, true) == 10
        @test _compact_max_rows(10, false) == 5

        hdr = _compact_header_text("ABC", "50%", 12, 4)
        @test occursin('%', hdr)
        @test length(hdr) <= 10

        hdr2 = _compact_header_text("VeryLongColumn", "99%", 12, 4)
        @test occursin('…', hdr2) || length(hdr2) <= 10

        hdr3 = _compact_header_text("X", "3%", 9, 0)
        @test occursin('%', hdr3)

        stats = compute_missing_stats(bigtable(100, 3); max_rows=10, max_cols=20)
        label = _pair_row_label(stats, 1, 2)
        @test occursin('-', label)
        @test label == string(stats.row_lo[1], "-", stats.row_hi[2])
    end

    # =========================================================================
    # render_grid_compact! and render_summary_compact!
    # =========================================================================
    @testset "render_grid_compact! and render_summary_compact!" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6])
        stats = compute_missing_stats(tbl; max_rows=50, max_cols=20)
        style = _make_render_style(IOBuffer(); cell_chars=5, char_missing='█',
                                     char_present='░', name_width=4, color_cells=false)

        buf = IOBuffer()
        render_grid_compact!(buf, stats, style; halfblock=false)
        out = String(take!(buf))
        @test occursin('┏', out) && occursin('┛', out)
        @test occursin('%', out)

        buf_s = IOBuffer()
        render_summary_compact!(buf_s, stats, style)
        summary = String(take!(buf_s))
        @test occursin("missing", summary) && occursin("present", summary)
        @test occursin("×", summary)
    end

    # =========================================================================
    # compact layout
    # =========================================================================
    @testset "compact layout respects target_lines" begin
        tbl = bigtable()
        for (target, colormode) in ((28, :always), (28, :never), (20, :always))
            out = rendered(plotmissing, tbl; layout=:compact,
                           target_lines=target, color=colormode)
            nlines = count(==('\n'), out)
            @test nlines <= target
            @test occursin('┏', out) && occursin('┗', out)
        end
        small = (a = [1, missing], b = [2, 3])
        @test occursin("Compression:", rendered(plotmissing, small; color=:never))
        @test !occursin("Compression:",
                        rendered(plotmissing, tbl; color=:never, target_lines=28))
    end

    @testset "half-block doubling" begin
        halfblock_rows = _compact_max_rows(28, true)
        glyph_rows = _compact_max_rows(28, false)
        @test halfblock_rows == 2 * glyph_rows
        out = rendered(plotmissing, bigtable(); layout=:compact, color=:always)
        @test occursin('▀', out)
        @test !occursin('▀', rendered(plotmissing, bigtable();
                                       layout=:compact, color=:never))
    end

    # =========================================================================
    # plotmissing classic layout basics
    # =========================================================================
    @testset "plotmissing classic layout features" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6])
        @test nothing === plotmissing(IOBuffer(), tbl; layout=:classic, color=:never)
        @test nothing === plotmissing(tbl)

        # custom chars
        out = rendered(plotmissing, tbl; char_missing='X', char_present='.',
                       layout=:classic, color=:never)
        @test occursin('X', out) && occursin('.', out)

        # custom cell_chars
        out2 = rendered(plotmissing, tbl; cell_chars=3, layout=:classic, color=:never)
        @test occursin('█', out2)

        # show_row_range
        out3 = rendered(plotmissing, tbl; show_row_range=true, layout=:classic,
                        color=:never)
        @test occursin("row", out3)
        @test occursin("1", out3)

        # name_width
        tbl_long = (LongColumnName = [1, 2], B = [3, 4])
        out4 = rendered(plotmissing, tbl_long;
                        name_width=4, layout=:classic, color=:never)
        @test occursin("Long…", out4)

        out5 = rendered(plotmissing, tbl_long;
                        name_width=0, layout=:classic, color=:never)
        @test occursin("Long", out5)

        # no missing values
        tbl_full = (A = [1, 2, 3], B = [4, 5, 6])
        out6 = rendered(plotmissing, tbl_full; layout=:classic, color=:never)
        @test occursin("MissingPatterns.Analysis:", out6)

        # all missing values
        tbl_allmissing = (A = [missing, missing], B = [missing, missing])
        out7 = strip_ansi(rendered(plotmissing, tbl_allmissing; layout=:classic,
                                   color=:always))
        m = match(r"Missing \(count\):\s+(\d+)", out7)
        @test m !== nothing && parse(Int, m[1]) == 4

        # single row
        tbl_row = (A = [1], B = [missing], C = [3])
        out8 = rendered(plotmissing, tbl_row; layout=:classic, color=:never)
        @test occursin("MissingPatterns.Analysis:", out8)

        # single column
        tbl_col = (A = [1, missing, 3, missing, 5],)
        out9 = rendered(plotmissing, tbl_col; layout=:classic, color=:never)
        @test occursin('┃', out9) && occursin('%', out9)
    end

    # =========================================================================
    # plotmissing layout=:auto
    # =========================================================================
    @testset "plotmissing layout=:auto resolution" begin
        small = (a = [1, 2], b = [3, 4])
        out_s = rendered(plotmissing, small; layout=:auto, color=:never, target_lines=28)
        @test occursin("MissingPatterns.Analysis:", out_s)

        big = bigtable(200, 5)
        out_b = rendered(plotmissing, big; layout=:auto, color=:never, target_lines=20)
        @test occursin("×", out_b)
    end

    # =========================================================================
    # plotmissing color kwarg
    # =========================================================================
    @testset "plotmissing color kwarg" begin
        tbl = (A = [1, missing], B = [3, 4])
        out_color = rendered(plotmissing, tbl; color=:always)
        @test occursin("\033[", out_color)

        out_no = rendered(plotmissing, tbl; color=:never)
        @test !occursin("\033[", out_no)
    end

    # =========================================================================
    # plotmissing emphasis and missing_color
    # =========================================================================
    @testset "plotmissing emphasis and missing_color" begin
        tbl = (A = [1, missing], B = [missing, 2])
        out_p = rendered(plotmissing, tbl; layout=:classic, color=:always,
                         color_cells=true, emphasis=:present, missing_color="#00ff00")
        @test occursin("\033[", out_p)

        out_m = rendered(plotmissing, tbl; layout=:classic, color=:always,
                         color_cells=true, emphasis=:missing, missing_color="#0000ff")
        @test occursin("\033[", out_m)

        out_c = rendered(plotmissing, tbl; layout=:compact, color=:always,
                         emphasis=:present, missing_color="#ff0000")
        @test occursin("\033[", out_c)
    end

    # =========================================================================
    # temporal grouping
    # =========================================================================
    @testset "temporal grouping" begin
        dates = vcat(fill(Date(2024, 1, 15), 4), fill(Date(2025, 6, 1), 4),
                     [missing, missing])
        vals = [1, missing, 3, 4, missing, missing, 7, 8, missing, 10]
        tbl = (date = dates, v = vals)

        s = compute_missing_stats_grouped(tbl, :date, :year; max_rows=50, max_cols=20)
        @test s.dr == 3
        @test s.row_labels == ["2024", "2025", "∅"]
        @test s.group_desc == "by date (year)"
        jv = findfirst(==("v"), s.colnames)
        @test s.proportions[1, jv] ≈ 0.25
        @test s.proportions[2, jv] ≈ 0.5

        out = rendered(plotmissing, tbl; by=:date, period=:year, color=:never)
        @test occursin("2024", out) && occursin("2025", out)
        @test occursin("by date (year)", out)

        sq = compute_missing_stats_grouped(tbl, :date, :quarter; max_rows=50, max_cols=20)
        @test "2024-Q1" in sq.row_labels

        sm = compute_missing_stats_grouped(tbl, :date, :month; max_rows=50, max_cols=20)
        @test occursin('-', sm.row_labels[1])

        # period=:day
        dt = (date = [Date(2024, 1, 1), Date(2024, 1, 1), Date(2024, 1, 2)],
              v = [1, missing, 3])
        sd = compute_missing_stats_grouped(dt, :date, :day; max_rows=50, max_cols=20)
        @test "2024-01-01" in sd.row_labels

        # period=:week
        sw = compute_missing_stats_grouped(tbl, :date, :week; max_rows=50, max_cols=20)
        @test any(l -> occursin("W", l), sw.row_labels)

        @test_throws ArgumentError compute_missing_stats_grouped(tbl, :nope, :year;
                                                                  max_rows=50, max_cols=20)
        @test_throws ArgumentError compute_missing_stats_grouped((a=[1, 2],), :a, :year;
                                                                  max_rows=50, max_cols=20)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; by=:a, period=:decade)
    end

    # =========================================================================
    # compute_cooccurrence
    # =========================================================================
    @testset "cooccurrence" begin
        tbl = (a = [missing, missing, 3, 4, 5, 6, 7, 8, 9, 10],
               b = [missing, missing, 3, 4, 5, 6, 7, 8, 9, 10],
               c = [1, 2, missing, 4, 5, missing, 7, 8, 9, 10])
        M, names_, n1, n = compute_cooccurrence(tbl; method=:phi)
        ia, ib = findfirst(==("a"), names_), findfirst(==("b"), names_)
        @test M[ia, ib] ≈ 1.0
        MJ, _, _, _ = compute_cooccurrence(tbl; method=:jaccard)
        @test MJ[ia, ib] ≈ 1.0

        tbl2 = (a = [missing, 2], b = [1, 2])
        M2, names2, _, _ = compute_cooccurrence(tbl2)
        @test isnan(M2[1, 2])

        @test_throws ArgumentError compute_cooccurrence(tbl; method=:tau)
    end

    # =========================================================================
    # missingcooccurrence
    # =========================================================================
    @testset "missingcooccurrence" begin
        tbl = (a = [missing, missing, 3, 4, 5, 6, 7, 8, 9, 10],
               b = [missing, missing, 3, 4, 5, 6, 7, 8, 9, 10],
               c = [1, 2, missing, 4, 5, missing, 7, 8, 9, 10])
        out = rendered(missingcooccurrence, tbl; color=:never)
        @test occursin("1.00", out) && occursin("pairwise ϕ", out)
        @test occursin("—", out)

        out_j = rendered(missingcooccurrence, tbl; method=:jaccard, color=:never)
        @test occursin("J", out_j) && !occursin("ϕ", out_j)

        wide = bigtable(200, 25)
        outw = rendered(missingcooccurrence, wide; color=:never, max_cols=10)
        @test occursin("omitted", outw)

        @test nothing === missingcooccurrence(IOBuffer(), tbl; color=:always)
        @test nothing === missingcooccurrence(tbl)
    end

    # =========================================================================
    # missingsummary
    # =========================================================================
    @testset "missingsummary" begin
        tbl = (x = [1, missing, 3, missing], y = ["a", "b", "c", "d"])
        out = strip_ansi(rendered(missingsummary, tbl; color=:always))
        @test occursin("column", out) && occursin("distribution", out)
        @test occursin("50.00%", out)
        @test occursin("0.00%", out)
        @test any(c -> c in "▁▂▃▄▅▆▇█", out)

        first_data_line = split(rendered(missingsummary, tbl; color=:never), '\n')[2]
        @test startswith(lstrip(first_data_line), "x")

        out_n = rendered(missingsummary, tbl; sortby=:name, color=:never)
        first_line_n = split(out_n, '\n')[2]
        @test startswith(lstrip(first_line_n), "x")

        out_no = rendered(missingsummary, tbl; sortby=:none, color=:never)
        @test !isempty(out_no)

        out_bins = rendered(missingsummary, tbl; bins=2, color=:never)
        @test occursin("bins of 2 rows", out_bins)

        @test_throws ArgumentError missingsummary(IOBuffer(), tbl; sortby=:zodiac)
        @test_throws ArgumentError missingsummary(IOBuffer(), tbl; bins=0)
    end

    # =========================================================================
    # missingpatterns
    # =========================================================================
    @testset "missingpatterns" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
        out = rendered(missingpatterns, tbl; color_cells=false)
        @test occursin('┏', out) && occursin('┛', out)
        @test occursin("unique pattern", out)

        @test nothing === missingpatterns(tbl)

        tbl_empty = (A = Int[],)
        @test occursin("Empty table", rendered(missingpatterns, tbl_empty))

        tbl_full = (A = [1, 2, 3], B = [4, 5, 6])
        out2 = rendered(missingpatterns, tbl_full; color_cells=false)
        @test occursin("1 unique pattern", out2)
        @test occursin("100.0%", out2)

        tbl_miss = (A = [missing, missing], B = [missing, missing])
        out3 = rendered(missingpatterns, tbl_miss; color_cells=false)
        @test occursin("1 unique pattern", out3)

        tbl_one = (A = [1], B = [missing])
        out4 = rendered(missingpatterns, tbl_one; color_cells=false)
        @test occursin("1 unique pattern across 1 row", out4)

        # custom chars
        out5 = rendered(missingpatterns, (A=[1, missing], B=[missing, 2]);
                        char_missing='X', char_present='.', color_cells=false)
        @test occursin('X', out5) && occursin('.', out5)
    end

    @testset "missingpatterns bars & min_pct" begin
        tbl = (a = [missing, missing, missing, 4, 5, 6, 7, 8, 9, 10],
               b = [1, 2, 3, missing, 5, 6, 7, 8, 9, 10])
        out = rendered(missingpatterns, tbl; color_cells=false)
        @test occursin("freq", out) && occursin('█', out)
        filtered = rendered(missingpatterns, tbl; min_pct=20.0)
        @test occursin("below min_pct", filtered)
        no_bar = rendered(missingpatterns, tbl; show_bar=false)
        @test !occursin("freq", no_bar)

        @test_throws ArgumentError missingpatterns(IOBuffer(), tbl; min_pct=101.0)
        @test_throws ArgumentError missingpatterns(IOBuffer(), tbl; min_pct=-1.0)
        @test_throws ArgumentError missingpatterns(IOBuffer(), tbl; max_patterns=0)
        @test_throws ArgumentError missingpatterns(IOBuffer(), tbl; emphasis=:invalid)
    end

    # =========================================================================
    # plotmissingdiff
    # =========================================================================
    @testset "plotmissingdiff" begin
        before = (a = [missing, missing, 3, 4], b = [1, 2, 3, missing])
        after  = (a = [1, missing, 3, 4],       b = [1, 2, missing, missing])
        @test _diff_counts(before.a, after.a) == (1, 0)
        @test _diff_counts(before.b, after.b) == (0, 1)
        @test _diff_rgb(0.0, (255, 0, 0), (0, 255, 0)) == _PRESENT_RGB
        @test _diff_rgb(1e-4, (255, 0, 0), (0, 255, 0)) != _PRESENT_RGB
        @test _diff_rgb(-1e-4, (255, 0, 0), (0, 255, 0)) != _PRESENT_RGB

        out = rendered(plotmissingdiff, before, after; color=:never)
        @test occursin("resolved 1", out) && occursin("introduced 1", out)
        nlines = count(==('\n'), out)
        @test nlines <= 28

        out_c = rendered(plotmissingdiff, before, after; color=:always)
        @test occursin("\033[", out_c)

        # no-color fallback has +, -, · glyphs
        out_nc = rendered(plotmissingdiff, before, after; color=:never)
        @test occursin('+', out_nc) || occursin('-', out_nc) || occursin('·', out_nc)

        @test_throws ArgumentError plotmissingdiff(IOBuffer(), before, (a=[1],))
        @test_throws ArgumentError plotmissingdiff(IOBuffer(), before,
                                                    (x=[1,2,3,4], y=[1,2,3,4]))

        @test nothing === plotmissingdiff(before, after)
    end

    # =========================================================================
    # missinghtml
    # =========================================================================
    @testset "missinghtml" begin
        tbl = (a = [1, missing, 3], b = [missing, 2, 3])
        html = missinghtml(tbl)
        @test occursin("<div", html) && occursin("grid-template-columns", html)
        @test occursin("rgb(243,169,169)", html)
        @test occursin("missing", html)
        htmlm = missinghtml(tbl; emphasis=:missing)
        @test occursin("rgb(48,48,54)", htmlm)

        path = joinpath(mktempdir(), "miss.html")
        @test missinghtml(path, tbl) == path
        @test isfile(path) && occursin("<div", read(path, String))

        @test occursin("Empty table", missinghtml((;)))

        html_title = missinghtml(tbl; title="My Heatmap")
        @test occursin("My Heatmap", html_title)

        html_c = missinghtml(tbl; missing_color="#ff0000")
        @test occursin("rgb(255,0,0)", html_c)

        html_empty = missinghtml((a=[1,2], b=[3,4]))
        @test occursin("rgb(48,48,54)", html_empty) || occursin("rgb(243", html_empty)
    end

    # =========================================================================
    # plotmissingdiff compact / no-color
    # =========================================================================
    @testset "plotmissingdiff no-color fallback" begin
        before = (a = [missing, 2, missing, 4], b = [1, missing, 3, missing])
        after  = (a = [1, missing, 3, 4],       b = [1, 2, missing, 4])
        out = rendered(plotmissingdiff, before, after; color=:never)
        @test occursin("resolved", out) && occursin("introduced", out)
        @test occursin('┏', out) && occursin('┛', out)
    end

    # =========================================================================
    # Temporal grouping with compression
    # =========================================================================
    @testset "temporal grouping compression" begin
        dates = [Date(2000, m, 1) for m in 1:12 for _ in 1:3]
        vals = [i % 17 == 0 ? missing : Float64(i) for i in 1:length(dates)]
        tbl = (date = dates, v = vals)
        s = compute_missing_stats_grouped(tbl, :date, :month; max_rows=5, max_cols=20)
        @test s.dr <= 5
        @test s.needs_compression
        out = rendered(plotmissing, tbl; by=:date, period=:month, max_rows=5,
                       layout=:classic, color=:never)
        @test occursin("by date (month)", out)
    end

    # =========================================================================
    # Argument validation
    # =========================================================================
    @testset "argument validation" begin
        tbl = (a = [1, missing],)

        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; layout=:banana)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; color=:sometimes)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; emphasis=:both)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; target_lines=3)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; missing_color="red")
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; cell_chars=0)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; cell_chars=81)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; name_width=-1)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; max_rows=0)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; max_cols=0)
        @test_throws ArgumentError missingpatterns(IOBuffer(), tbl; min_pct=101.0)
        @test_throws ArgumentError missingsummary(IOBuffer(), tbl; sortby=:zodiac)
        @test_throws ArgumentError missingcooccurrence(IOBuffer(), tbl; method=:tau)
        @test_throws ArgumentError plotmissing(IOBuffer(), tbl; by=:a, period=:decade)
    end

    # =========================================================================
    # Tables.jl compatibility: CSV.File-like tuple of vectors
    # =========================================================================
    @testset "Tables.jl NamedTuple compatibility" begin
        tbl = (col_a = [1.0, missing, 3.0], col_b = [missing, "x", "y"],
               col_c = [Date(2024, 1, 1), Date(2024, 2, 1), missing])

        @test isa(rendered(plotmissing, tbl; color=:never), String)
        @test isa(rendered(missingpatterns, tbl; color_cells=false), String)
        @test isa(rendered(missingsummary, tbl; color=:never), String)
        @test isa(rendered(missingcooccurrence, tbl; color=:never), String)
        @test isa(missinghtml(tbl), String)
    end

    # =========================================================================
    # plotmissing default IO is stdout
    # =========================================================================
    @testset "default IO" begin
        @test nothing === plotmissing((a=[1, missing],))
        @test nothing === missingpatterns((a=[1, missing],))
        @test nothing === missingsummary((a=[1, missing],))
        @test nothing === missingcooccurrence((a=[1, missing, 3], b=[missing, 2, 3]))
    end

    # =========================================================================
    # Output is valid UTF-8
    # =========================================================================
    @testset "output is valid UTF-8" begin
        tbl = (A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
        out = rendered(plotmissing, tbl; layout=:classic, color=:never)
        @test isvalid(out)
        out_p = rendered(missingpatterns, tbl; color_cells=false)
        @test isvalid(out_p)
        out_s = rendered(missingsummary, tbl; color=:never)
        @test isvalid(out_s)
    end

    # =========================================================================
    # Unicode column names
    # =========================================================================
    @testset "Unicode column names" begin
        df = DataFrame("ação_com_acentos" => [1, missing, 3],
                       "niño_español" => [missing, 5, 6])
        out = rendered(plotmissing, df; name_width=4, layout=:classic, color=:never)
        @test isvalid(out)
        @test occursin("açã", out) || occursin("ação", out)
        @test occursin("niñ", out) || occursin("niño", out)
    end

end