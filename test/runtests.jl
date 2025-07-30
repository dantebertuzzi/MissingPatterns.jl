using MissingPatterns
using Test
using DataFrames

@testset "MissingPatterns.jl" begin
    # Teste básico
    df = DataFrame(A = [1, missing, 3], B = [missing, 5, 6], C = [7, 8, missing])
    
    # Verifica se a função não gera erro
    @test nothing == plotmissing(df)
    
    # Teste com DataFrame vazio
    df_empty = DataFrame(A = Int[], B = String[])
    @test nothing == plotmissing(df_empty)
    
    # Teste com DataFrame sem missing values
    df_no_missing = DataFrame(A = [1, 2, 3], B = [4, 5, 6])
    @test nothing == plotmissing(df_no_missing)
end
