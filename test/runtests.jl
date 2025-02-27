using MissingPatterns
using Test
using DataFrames


@testset "MissingPatterns.jl" begin

df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
plotmissing(df)
    
    
end
