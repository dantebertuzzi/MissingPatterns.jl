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
        @test nothing === plotmissing(io, df; max_rows=20, max_cols=20)
        output = String(take!(io))
        @test occursin("Compression:", output)
        @test !occursin("No compression needed", output)
        @test occursin("Ratio:", output)
    end

    @testset "compression: many columns" begin
        n = 3
        df = DataFrame([Symbol("col$i") => rand([rand(), missing], n) for i in 1:30])
        io = IOBuffer()
        @test nothing === plotmissing(io, df; max_rows=50, max_cols=10)
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
        @test nothing === plotmissing(io, df; max_rows=3, max_cols=1)
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
        @test nothing === plotmissing(io, df; max_cols=10)
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

end
