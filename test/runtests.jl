using MissingPatterns
using Test
using DataFrames

@testset "MissingPatterns.jl" begin

    @testset "basic functionality" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
        io = IOBuffer()
        @test nothing === plotmissing(io, df)
        output = String(take!(io))
        @test occursin("MissingPatterns.Analysis:", output)
        @test occursin('┏', output)
        @test occursin('┓', output)
        @test occursin('┗', output)
        @test occursin('┛', output)
        @test occursin("Missing (count):", output)
        @test occursin("Present (count):", output)
        @test occursin("Progress Bar:", output)
    end

    @testset "default IO is stdout" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        @test nothing === plotmissing(df)
    end

    @testset "empty DataFrame" begin
        io = IOBuffer()
        @test nothing === plotmissing(io, DataFrame(A = Int[], B = String[]))
        output = String(take!(io))
        @test occursin("nothing to display", output)

        io2 = IOBuffer()
        @test nothing === plotmissing(io2, DataFrame())
        @test occursin("nothing to display", String(take!(io2)))
    end

    @testset "no missing values" begin
        df = DataFrame(A = [1, 2, 3], B = [4, 5, 6])
        io = IOBuffer()
        @test nothing === plotmissing(io, df)
        output = String(take!(io))
        @test occursin("MissingPatterns.Analysis:", output)
        @test occursin("Missing (count):", output)
    end

    @testset "all missing values" begin
        df = DataFrame(A = [missing, missing, missing], B = [missing, missing, missing])
        io = IOBuffer()
        @test nothing === plotmissing(io, df)
        output = String(take!(io))
        sanitized = replace(output, r"\e\[[0-9;]*m" => "")
        @test occursin("MissingPatterns.Analysis:", sanitized)
        matched = match(r"Missing \(count\):\s+(\d+)", sanitized)
        @test matched !== nothing
        @test parse(Int, matched[1]) == 6
    end

    @testset "single row" begin
        df = DataFrame(A = [1], B = [missing], C = [3])
        io = IOBuffer()
        @test nothing === plotmissing(io, df)
        output = String(take!(io))
        @test occursin("MissingPatterns.Analysis:", output)
    end

    @testset "single column" begin
        df = DataFrame(A = [1, missing, 3, missing, 5])
        io = IOBuffer()
        @test nothing === plotmissing(io, df)
        output = String(take!(io))
        @test occursin("MissingPatterns.Analysis:", output)
        @test occursin('┃', output)
    end

    @testset "custom characters" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; char_missing='X', char_present='.')
        output = String(take!(io))
        @test occursin('X', output)
        @test occursin('.', output)
    end

    @testset "custom cell_chars" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; cell_chars=3)
        output = String(take!(io))
        @test occursin("MissingPatterns.Analysis:", output)

        io2 = IOBuffer()
        @test nothing === plotmissing(io2, df; cell_chars=10)
        @test occursin("MissingPatterns.Analysis:", String(take!(io2)))
    end

    @testset "char_width deprecation (backward compat)" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        io = IOBuffer()
        @test_logs (:warn, r"deprecated.*cell_chars") begin
            @test nothing === plotmissing(io, df; char_width=3)
        end
        output = String(take!(io))
        @test occursin("MissingPatterns.Analysis:", output)
    end

    @testset "compression: many rows" begin
        n = 100
        df = DataFrame([Symbol("col$i") => rand([rand(), missing], n) for i in 1:5])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; max_rows=20, max_cols=20, layout=:classic)
        output = String(take!(io))
        @test occursin("Compression:", output)
        @test !occursin("No compression needed", output)
        @test occursin("Ratio:", output)
    end

    @testset "compression: many columns" begin
        n = 3
        df = DataFrame([Symbol("col$i") => rand([rand(), missing], n) for i in 1:30])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; max_rows=50, max_cols=10, layout=:classic)
        output = String(take!(io))
        @test occursin("Compression:", output)
        @test !occursin("No compression needed", output)
    end

    @testset "no compression needed" begin
        df = DataFrame(A = [1, 2], B = [3, 4])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; max_rows=50, max_cols=20)
        output = String(take!(io))
        @test occursin("No compression needed", output)
    end

    @testset "custom max_rows and max_cols" begin
        df = DataFrame(A = [1, 2, 3, 4, 5], B = [6, 7, 8, 9, 10])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; max_rows=3, max_cols=1, layout=:classic)
        output = String(take!(io))
        @test occursin("Compression:", output)
    end

    @testset "type stability" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        result = @inferred plotmissing(IOBuffer(), df)
        @test result === nothing
    end

    @testset "parameter validation" begin
        df = DataFrame(A = [1, 2], B = [3, 4])

        @test_throws ArgumentError plotmissing(df; cell_chars=0)
        @test_throws ArgumentError plotmissing(df; cell_chars=-1)
        @test_throws ArgumentError plotmissing(df; cell_chars=81)
        @test_throws ArgumentError plotmissing(df; name_width=-1)
        @test_throws ArgumentError plotmissing(df; max_rows=0)
        @test_throws ArgumentError plotmissing(df; max_rows=-5)
        @test_throws ArgumentError plotmissing(df; max_cols=0)
        @test_throws ArgumentError plotmissing(df; max_cols=-1)
    end

    @testset "output is valid UTF-8" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
        io = IOBuffer()
        plotmissing(io, df)
        output = String(take!(io))
        @test isvalid(output)
    end

    @testset "very wide single-row DataFrame" begin
        df = DataFrame([Symbol("col$i") => [i] for i in 1:30])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; max_cols=10, layout=:classic)
        output = String(take!(io))
        @test occursin("Compression:", output)
    end

    @testset "summary statistics are correct" begin
        df = DataFrame(
            A = [1, missing, 3, missing, 5],
            B = [missing, 7, missing, 9, missing]
        )
        io = IOBuffer()
        plotmissing(io, df)
        output = String(take!(io))
        sanitized = replace(output, r"\e\[[0-9;]*m" => "")
        matched = match(r"Missing \(count\):\s+(\d+)", sanitized)
        @test matched !== nothing
        @test parse(Int, matched[1]) == 5
    end

    @testset "progress bar present" begin
        df = DataFrame(A = [1, missing], B = [3, 4])
        io = IOBuffer()
        plotmissing(io, df)
        output = String(take!(io))
        @test occursin("Progress Bar:", output)
    end

    @testset "box-drawing characters are correct" begin
        df = DataFrame(A = [1, 2], B = [3, 4])
        io = IOBuffer()
        plotmissing(io, df)
        output = String(take!(io))
        @test occursin('┏', output)
        @test occursin('┓', output)
        @test occursin('┣', output)
        @test occursin('┫', output)
        @test occursin('┗', output)
        @test occursin('┛', output)
        @test occursin('┃', output)
        @test occursin('━', output)
    end

    @testset "cell_chars upper bound" begin
        df = DataFrame(A = [1, 2], B = [3, 4])
        @test_throws ArgumentError plotmissing(df; cell_chars=81)
        @test_throws ArgumentError plotmissing(df; cell_chars=1000)
        @test nothing === plotmissing(IOBuffer(), df; cell_chars=80)
    end

    @testset "Unicode column names" begin
        df = DataFrame("ação_com_acentos" => [1, missing, 3],
                       "niño_español" => [missing, 5, 6])
        io = IOBuffer()
        @test nothing === plotmissing(io, df)
        output = String(take!(io))
        @test isvalid(output)
        @test occursin("ação…", output)
        @test occursin("niño…", output)
    end

    @testset "custom name_width" begin
        df = DataFrame("coluna_alfa" => [1, missing, 3],
                       "coluna_beta" => [missing, 5, 6],
                       "coluna_gama" => [7, 8, missing])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; name_width=6)
        output = String(take!(io))
        @test occursin("coluna…", output)

        io2 = IOBuffer()
        @test nothing === plotmissing(io2, df; name_width=0)
        output2 = String(take!(io2))
        @test occursin("coluna_", output2)
    end

    @testset "name_width zero shows full names" begin
        df = DataFrame("abc" => [1, missing], "xyz" => [missing, 3])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; name_width=0)
        output = String(take!(io))
        @test occursin("abc", output)
        @test occursin("xyz", output)
    end

    @testset "progress bar adapts to terminal width" begin
        df = DataFrame(A = [1, missing], B = [3, 4])
        io = IOBuffer()
        plotmissing(io, df)
        output = String(take!(io))
        @test occursin("Progress Bar:", output)
        @test occursin('[', output)
        @test occursin(']', output)
        bar_line = only(filter(l -> startswith(l, " Progress Bar:"), split(output, '\n')))
        bar_start = findfirst('[', bar_line)
        bar_end = findlast(']', bar_line)
        @test bar_start !== nothing && bar_end !== nothing
        bar_nchars = length(bar_line) - bar_start[1] - (lastindex(bar_line) - bar_end[1])
        @test bar_nchars >= 2
    end

    @testset "ANSI codes disabled for IOBuffer" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        io = IOBuffer()
        plotmissing(io, df)
        output = String(take!(io))
        @test !occursin("\033[34m", output)
        @test !occursin("\033[38;5;208m", output)
        @test !occursin("\033[0m", output)
    end

    @testset "output captured via IOBuffer is readable" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
        io = IOBuffer()
        plotmissing(io, df)
        result = String(take!(io))
        @test !isempty(result)
        lines = split(result, '\n')
        @test length(lines) >= 10
        @test occursin('█', result)
        @test occursin('░', result)
    end

    @testset "missingpatterns" begin

        @testset "basic functionality" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
            io = IOBuffer()
            @test nothing === missingpatterns(io, df)
            output = String(take!(io))
            @test occursin('┏', output)
            @test occursin('┓', output)
            @test occursin('┗', output)
            @test occursin('┛', output)
            @test occursin("unique pattern", output)
        end

        @testset "default IO is stdout" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            @test nothing === missingpatterns(df)
        end

        @testset "empty DataFrame" begin
            io = IOBuffer()
            @test nothing === missingpatterns(io, DataFrame(A = Int[], B = String[]))
            @test occursin("nothing to display", String(take!(io)))

            io2 = IOBuffer()
            @test nothing === missingpatterns(io2, DataFrame())
            @test occursin("nothing to display", String(take!(io2)))
        end

        @testset "no missing values -> single pattern" begin
            df = DataFrame(A = [1, 2, 3], B = [4, 5, 6])
            io = IOBuffer()
            missingpatterns(io, df)
            output = String(take!(io))
            @test occursin("1 unique pattern across 3 rows", output)
            @test occursin("100.0%", output)
            @test occursin('░', output)
            @test !occursin('█', output)
        end

        @testset "all missing values -> single pattern" begin
            df = DataFrame(A = [missing, missing], B = [missing, missing])
            io = IOBuffer()
            missingpatterns(io, df)
            output = String(take!(io))
            @test occursin("1 unique pattern across 2 rows", output)
            @test occursin("100.0%", output)
        end

        @testset "singular row wording" begin
            df = DataFrame(A = [1], B = [missing])
            io = IOBuffer()
            missingpatterns(io, df)
            output = String(take!(io))
            @test occursin("1 unique pattern across 1 row", output)
            @test !occursin("1 rows", output)
        end

        @testset "identifies columns missing together" begin
            # A and B are always missing together; C is independent.
            df = DataFrame(
                A = [1, missing, 3, missing, 5, 6],
                B = [1, missing, 3, missing, 5, 6],
                C = [missing, 2, 3, 4, missing, 6],
            )
            stats = MissingPatterns.compute_pattern_stats(df)
            @test sum(stats.counts) == 6
            @test issorted(stats.counts; rev = true)
            for i in eachindex(stats.counts)
                @test stats.pattern_missing[i, 1] == stats.pattern_missing[i, 2]
end
    end

end

        @testset "max_patterns truncation" begin
            df = DataFrame([Symbol("c$i") => [rand() < 0.5 ? missing : 1 for _ in 1:50]
                            for i in 1:6])
            io = IOBuffer()
            missingpatterns(io, df; max_patterns=2)
            output = String(take!(io))
            @test occursin("showing top 2", output)
            @test occursin("more not shown", output)

            @test_throws ArgumentError missingpatterns(df; max_patterns=0)
            @test_throws ArgumentError missingpatterns(df; max_patterns=-1)
        end

        @testset "parameter validation shared with plotmissing" begin
            df = DataFrame(A = [1, 2], B = [3, 4])
            @test_throws ArgumentError missingpatterns(df; cell_chars=0)
            @test_throws ArgumentError missingpatterns(df; cell_chars=81)
            @test_throws ArgumentError missingpatterns(df; name_width=-1)
        end

        @testset "custom characters and color_cells accepted" begin
            df = DataFrame(A = [1, missing], B = [missing, 2])
            io = IOBuffer()
            @test nothing === missingpatterns(io, df; char_missing='X', char_present='.',
                                               color_cells=true)
            output = String(take!(io))
            @test occursin('X', output)
            @test occursin('.', output)
        end

        @testset "compute_pattern_stats is pure and type-stable" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            stats = @inferred MissingPatterns.compute_pattern_stats(df)
            @test stats.nrows == 3
            @test stats.ncols == 2
            @test sum(stats.counts) == 3
            @test size(stats.pattern_missing, 2) == 2
        end

        @testset "wide DataFrame (>64 columns) fallback path" begin
            n = 40
            ncols = 70
            df = DataFrame([Symbol("c$i") => [rand() < 0.2 ? missing : 1 for _ in 1:n]
                            for i in 1:ncols])
            stats = MissingPatterns.compute_pattern_stats(df)
            @test sum(stats.counts) == n
            @test size(stats.pattern_missing) == (length(stats.counts), ncols)

            io = IOBuffer()
            @test nothing === missingpatterns(io, df; max_patterns=5)
            @test occursin("unique pattern", String(take!(io)))
        end

        @testset "type stability of public entrypoint" begin
            df = DataFrame(A = [1, missing], B = [missing, 2])
            result = @inferred missingpatterns(IOBuffer(), df)
            @test result === nothing
        end

    end

    # =========================================================================
    # New tests for refactored architecture (v0.2.0+)
    # =========================================================================

    @testset "_use_color" begin
        io = IOBuffer()
        @test !MissingPatterns._use_color(io)
        ctx_on = IOContext(io, :color => true)
        @test MissingPatterns._use_color(ctx_on)
        ctx_off = IOContext(io, :color => false)
        @test !MissingPatterns._use_color(ctx_off)
    end

    @testset "_cell_glyph" begin
        @test MissingPatterns._cell_glyph(0.0, 'X', '.') == '.'
        @test MissingPatterns._cell_glyph(1.0, 'X', '.') == 'X'
        @test MissingPatterns._cell_glyph(-0.5, 'X', '.') == '.'
        @test MissingPatterns._cell_glyph(2.0, 'X', '.') == 'X'
        @test MissingPatterns._cell_glyph(0.1, '█', '░') == '░'
        @test MissingPatterns._cell_glyph(0.2, '█', '░') == '▒'
        @test MissingPatterns._cell_glyph(0.4, '█', '░') == '▓'
        @test MissingPatterns._cell_glyph(0.6, '█', '░') == '█'
    end

    @testset "compute_missing_stats" begin
        @testset "small frame (no compression)" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            stats = @inferred MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=20, show_row_range=false)
            @test stats.nrows == 3
            @test stats.ncols == 2
            @test stats.dr == 3
            @test stats.dc == 2
            @test !stats.needs_compression
            @test stats.rows_per_cell == 1
            @test stats.cols_per_cell == 1
            @test stats.missing_count == 2
            @test stats.total_cells == 6
            @test stats.proportions[1, 1] == 0.0
            @test stats.proportions[2, 1] == 1.0
            @test stats.proportions[1, 2] == 1.0
            @test stats.proportions[2, 2] == 0.0
            @test isempty(stats.row_labels)
        end

        @testset "with row labels" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=20, show_row_range=true)
            @test length(stats.row_labels) == 3
            @test stats.row_labels == ["1", "2", "3"]
        end

        @testset "compression needed (rows)" begin
            df = DataFrame(A = rand([1, missing], 100), B = rand([1, missing], 100))
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=20, max_cols=20, show_row_range=false)
            @test stats.needs_compression
            @test stats.dr <= 20
            @test stats.dc == 2
            @test stats.rows_per_cell > 1
            @test stats.cols_per_cell == 1
            @test stats.missing_count + (stats.total_cells - stats.missing_count) == stats.total_cells
            @test all(x -> 0.0 <= x <= 1.0, stats.proportions)
            @test all(x -> 0.0 <= x <= 100.0, stats.col_header_pct)
        end

        @testset "compression needed (columns)" begin
            n = 5
            df = DataFrame([Symbol("c$i") => rand([1, missing], n) for i in 1:30])
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=10, show_row_range=false)
            @test stats.needs_compression
            @test stats.dr == 5
            @test stats.dc <= 10
            @test stats.cols_per_cell > 1
        end

        @testset "colnames compressed vs not" begin
            df = DataFrame(a=[1], b=[2], c=[3])
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=20, show_row_range=false)
            @test stats.colnames == ["a", "b", "c"]
        end

        @testset "col_header_pct correctness" begin
            df = DataFrame(A = [missing, 2, 3], B = [1, missing, missing], C = [1, 2, 3])
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=20, show_row_range=false)
            @test isapprox(stats.col_header_pct[1], 100/3; atol=0.01)
            @test isapprox(stats.col_header_pct[2], 200/3; atol=0.01)
            @test isapprox(stats.col_header_pct[3], 0.0; atol=0.01)
        end

        @testset "row labels with compression" begin
            df = DataFrame(A = rand([1, missing], 100), B = rand([1, missing], 100))
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=10, max_cols=20, show_row_range=true)
            @test length(stats.row_labels) == stats.dr
            @test occursin('-', stats.row_labels[end])
        end
    end

    @testset "ColorRamp and color helpers" begin
        @testset "_parse_hex" begin
            @test MissingPatterns._parse_hex("aabbcc") == (170, 187, 204)
            @test MissingPatterns._parse_hex("AABBCC") == (170, 187, 204)
            @test MissingPatterns._parse_hex("#f3a9a9") == (243, 169, 169)
            @test MissingPatterns._parse_hex("#000000") == (0, 0, 0)
            @test MissingPatterns._parse_hex("#ffffff") == (255, 255, 255)
            @test_throws ArgumentError MissingPatterns._parse_hex("abc")
            @test_throws ArgumentError MissingPatterns._parse_hex("nothex")
        end

        @testset "_blend" begin
            a = (0, 0, 0)
            b = (100, 100, 100)
            @test MissingPatterns._blend(a, b, 0.0) == (0, 0, 0)
            @test MissingPatterns._blend(a, b, 1.0) == (100, 100, 100)
            @test MissingPatterns._blend(a, b, 0.5) == (50, 50, 50)
        end

        @testset "ColorRamp construction" begin
            ramp = MissingPatterns.ColorRamp((0, 0, 0), (255, 255, 255), :present)
            @test ramp.emphasis === :present
            ramp2 = MissingPatterns.ColorRamp((0, 0, 0), (255, 255, 255), :missing)
            @test ramp2.emphasis === :missing
        end

        @testset "_ramp_rgb with :present emphasis" begin
            base = (10, 10, 10)
            target = (100, 100, 100)
            ramp = MissingPatterns.ColorRamp(base, target, :present)
            r_full = MissingPatterns._ramp_rgb(ramp, 0.0)
            @test r_full == target
            r_some = MissingPatterns._ramp_rgb(ramp, 0.51)
            @test r_some[1] < target[1]
            @test r_some[1] > base[1]
        end

        @testset "_ramp_rgb with :missing emphasis" begin
            base = (10, 10, 10)
            target = (100, 100, 100)
            ramp = MissingPatterns.ColorRamp(base, target, :missing)
            r_none = MissingPatterns._ramp_rgb(ramp, 0.0)
            @test r_none == base
            r_some = MissingPatterns._ramp_rgb(ramp, 0.51)
            @test r_some[1] > base[1]
            @test r_some[1] < target[1]
        end

        @testset "_glyph_prefix :present emphasis" begin
            base = (48, 48, 54)
            target = (243, 169, 169)
            style = MissingPatterns._make_render_style(stdout;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=true, force_color=true,
                emphasis=:present)
            @test !isempty(MissingPatterns._glyph_prefix(style, 0.0))
            @test !isempty(MissingPatterns._glyph_prefix(style, 0.5))
        end

        @testset "_glyph_prefix :missing emphasis" begin
            base = (48, 48, 54)
            target = (243, 169, 169)
            style = MissingPatterns._make_render_style(stdout;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=true, force_color=true,
                emphasis=:missing)
            @test isempty(MissingPatterns._glyph_prefix(style, 0.0))
            @test !isempty(MissingPatterns._glyph_prefix(style, 0.5))
        end

        @testset "_fg_rgb and _bg_rgb" begin
            fg = MissingPatterns._fg_rgb((100, 150, 200))
            @test startswith(fg, "\033[38;2;")
            bg = MissingPatterns._bg_rgb((50, 75, 100))
            @test startswith(bg, "\033[48;2;")
        end
    end

    @testset "_make_render_style" begin
        @testset "basic style (no color)" begin
            io = IOBuffer()
            style = MissingPatterns._make_render_style(io;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false)
            @test style.cell_chars == 5
            @test style.char_missing == '█'
            @test style.char_present == '░'
            @test style.name_width == 4
            @test !style.color_cells
            @test !style.use_color
            @test !style.show_row_range
            @test style.cw >= 7
            @test style.rw == 0
            @test isempty(style.rst)
            @test isempty(style.blue)
        end

        @testset "force_color=true" begin
            io = IOBuffer()
            style = MissingPatterns._make_render_style(io;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=true, force_color=true)
            @test style.use_color
            @test !isempty(style.rst)
            @test !isempty(style.blue)
            @test !isempty(style.orange)
        end

        @testset "force_color=false" begin
            io = IOBuffer()
            style = MissingPatterns._make_render_style(io;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=true, force_color=false)
            @test !style.use_color
        end

        @testset "with show_row_range" begin
            io = IOBuffer()
            labels = ["1", "2", "3"]
            style = MissingPatterns._make_render_style(io;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false, show_row_range=true,
                row_labels=labels)
            @test style.show_row_range
            @test style.rw >= 5
            @test !isempty(style.row_bar)
        end

        @testset "custom missing_color" begin
            io = IOBuffer()
            style = MissingPatterns._make_render_style(io;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false, force_color=true,
                missing_color="#ff0000")
            @test style.ramp.target == (255, 0, 0)
        end
    end

    @testset "plotmissing compact layout" begin
        @testset "layout=:compact works" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            io = IOBuffer()
            @test nothing === plotmissing(io, df; layout=:compact)
            output = String(take!(io))
            @test occursin('┏', output)
            @test occursin('┓', output)
            @test occursin('┗', output)
            @test occursin('┛', output)
            @test occursin("missing", output)
            @test occursin("present", output)
        end

        @testset "layout=:compact with many rows" begin
            df = DataFrame(A = rand([1, missing], 200), B = rand([1, missing], 200))
            io = IOBuffer()
            plotmissing(io, df; layout=:compact, target_lines=20)
            output = String(take!(io))
            lines = split(output, '\n'; keepempty=false)
            @test length(lines) <= 21  # target_lines + possible extra
            @test occursin("×", output)
        end

        @testset "layout=:classic explicit" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            io = IOBuffer()
            @test nothing === plotmissing(io, df; layout=:classic)
            output = String(take!(io))
            @test occursin("MissingPatterns.Analysis:", output)
        end

        @testset "invalid layout throws" begin
            df = DataFrame(A = [1])
            @test_throws ArgumentError plotmissing(df; layout=:invalid)
        end

        @testset "target_lines validation" begin
            df = DataFrame(A = [1])
            @test_throws ArgumentError plotmissing(df; layout=:compact, target_lines=5)
            @test nothing === plotmissing(IOBuffer(), df; layout=:compact, target_lines=6)
        end
    end

    @testset "plotmissing color kwarg" begin
        @testset "color=:always forces ANSI" begin
            df = DataFrame(A = [1, missing], B = [3, 4])
            io = IOBuffer()
            plotmissing(io, df; color=:always)
            output = String(take!(io))
            @test occursin("\033[", output)
        end

        @testset "color=:never suppresses ANSI" begin
            df = DataFrame(A = [1, missing], B = [3, 4])
            io = IOBuffer()
            plotmissing(io, df; color=:never)
            output = String(take!(io))
            @test !occursin("\033[", output)
        end

        @testset "invalid color throws" begin
            df = DataFrame(A = [1])
            @test_throws ArgumentError plotmissing(df; color=:invalid)
        end
    end

    @testset "plotmissing missing_color and emphasis kwargs" begin
        @testset "missing_color with compact layout" begin
            df = DataFrame(A = [1, missing], B = [missing, 2])
            io = IOBuffer()
            plotmissing(io, df; layout=:compact, color=:always, missing_color="#ff0000",
                        emphasis=:missing)
            output = String(take!(io))
            @test occursin("\033[", output)
        end

        @testset "emphasis=:present with classic layout" begin
            df = DataFrame(A = [1, missing], B = [missing, 2])
            io = IOBuffer()
            plotmissing(io, df; layout=:classic, color=:always, color_cells=true,
                        emphasis=:present, missing_color="#00ff00")
            output = String(take!(io))
            @test occursin("\033[", output)
        end

        @testset "emphasis=:missing with classic layout" begin
            df = DataFrame(A = [1, missing], B = [missing, 2])
            io = IOBuffer()
            plotmissing(io, df; layout=:classic, color=:always, color_cells=true,
                        emphasis=:missing, missing_color="#0000ff")
            output = String(take!(io))
            @test occursin("\033[", output)
        end

        @testset "invalid emphasis throws" begin
            df = DataFrame(A = [1])
            @test_throws ArgumentError plotmissing(df; emphasis=:invalid)
        end
    end

    @testset "plotmissing layout=:auto resolution" begin
        @testset "small frame uses classic" begin
            df = DataFrame(A = [1, 2], B = [3, 4])
            io = IOBuffer()
            plotmissing(io, df; layout=:auto, target_lines=28)
            output = String(take!(io))
            @test occursin("MissingPatterns.Analysis:", output)
        end

        @testset "large frame uses compact" begin
            df = DataFrame([Symbol("c$i") => rand([1, missing], 200) for i in 1:3])
            io = IOBuffer()
            plotmissing(io, df; layout=:auto, target_lines=20, max_rows=10)
            output = String(take!(io))
            @test occursin("missing", output)
        end
    end

    @testset "missingpatterns missing_color and emphasis" begin
        @testset "missing_color passed through" begin
            df = DataFrame(A = [1, missing], B = [missing, 2])
            io = IOBuffer()
            missingpatterns(io, df; missing_color="#ff0000", emphasis=:missing)
            output = String(take!(io))
            @test occursin("unique pattern", output)
        end

        @testset "emphasis validation" begin
            df = DataFrame(A = [1])
            @test_throws ArgumentError missingpatterns(df; emphasis=:invalid)
        end
    end

    @testset "render_grid! and render_summary!" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        stats = MissingPatterns.compute_missing_stats(df;
            max_rows=50, max_cols=20, show_row_range=false)
        style = MissingPatterns._make_render_style(IOBuffer();
            cell_chars=5, char_missing='█', char_present='░',
            name_width=4, color_cells=false)

        buf = IOBuffer()
        MissingPatterns.render_grid!(buf, stats, style)
        output = String(take!(buf))
        @test occursin('┏', output)
        @test occursin('┓', output)
        @test occursin('┗', output)
        @test occursin('┛', output)
        @test occursin('%', output)

        buf2 = IOBuffer()
        MissingPatterns.render_summary!(buf2, stats, style, stdout)
        summary = String(take!(buf2))
        @test occursin("MissingPatterns.Analysis:", summary)
        @test occursin("Missing (count):", summary)
        @test occursin("Present (count):", summary)
    end

    @testset "render_pattern_table!" begin
        df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
        stats = MissingPatterns.compute_pattern_stats(df)
        style = MissingPatterns._make_render_style(IOBuffer();
            cell_chars=5, char_missing='█', char_present='░',
            name_width=4, color_cells=false)

        buf = IOBuffer()
        shown = MissingPatterns.render_pattern_table!(buf, stats, style, 20)
        @test shown == length(stats.counts)
        output = String(take!(buf))
        @test occursin('┏', output)
        @test occursin('┓', output)
        @test occursin('┗', output)
        @test occursin('┛', output)
        @test occursin("n", output)
        @test occursin("%", output)
    end

    @testset "compact helpers" begin
        @testset "_compact_max_rows" begin
            @test MissingPatterns._compact_max_rows(28, true) == 46
            @test MissingPatterns._compact_max_rows(28, false) == 23
            @test MissingPatterns._compact_max_rows(10, true) == 10
            @test MissingPatterns._compact_max_rows(10, false) == 5
        end

        @testset "_compact_header_text" begin
            @test occursin('%', MissingPatterns._compact_header_text("ABC", 50.0, 12, 4))
            @test occursin('%', MissingPatterns._compact_header_text("X", 33.3, 9, 0))
            @test occursin('…', MissingPatterns._compact_header_text("VeryLongName", 10.0, 9, 10))
        end

        @testset "render_grid_compact! and render_summary_compact!" begin
            df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6])
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=20, show_row_range=false)
            style = MissingPatterns._make_render_style(IOBuffer();
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=false)

            buf = IOBuffer()
            MissingPatterns.render_grid_compact!(buf, stats, style; halfblock=false)
            output = String(take!(buf))
            @test occursin('┏', output)
            @test occursin('┛', output)

            buf2 = IOBuffer()
            MissingPatterns.render_summary_compact!(buf2, stats, style)
            summary = String(take!(buf2))
            @test occursin("missing", summary)
            @test occursin("present", summary)
            @test occursin("×", summary)
        end

        @testset "compact with halfblock color" begin
            df = DataFrame(A = [1, missing, 3, 4], B = [missing, 5, 6, missing])
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=50, max_cols=20, show_row_range=false)
            style = MissingPatterns._make_render_style(stdout;
                cell_chars=5, char_missing='█', char_present='░',
                name_width=4, color_cells=true, force_color=true)

            buf = IOBuffer()
            MissingPatterns.render_grid_compact!(buf, stats, style; halfblock=true)
            output = String(take!(buf))
            @test occursin('▀', output)
            @test occursin("\033[", output)
        end

        @testset "_pair_row_label" begin
            df = DataFrame(A = rand([1, missing], 100), B = rand([1, missing], 100))
            stats = MissingPatterns.compute_missing_stats(df;
                max_rows=10, max_cols=20, show_row_range=false)
            label = MissingPatterns._pair_row_label(stats, 1, 2)
            @test occursin('-', label)
        end
    end
