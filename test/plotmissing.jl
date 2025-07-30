using DataFrames
include("MissingPatterns.jl")

# Teste pequeno para referência
df = DataFrame(
    A = [1, missing, 3, 4, missing],
    B = [missing, 2, 3, missing, 5],
    C = [1, 2, missing, 4, 5]
)

# ...existing code...

# ...existing code...

# Teste grande: 200 linhas x 10 colunas, missing aleatório, nomes de colunas grandes
println("\nTeste extra (200 linhas x 10 colunas, nomes grandes):")
nrows, ncols = 200000, 10
colnames = ["ColunaMuitoLonga_$(i)" for i in 1:ncols]  # nomes grandes
data = [rand() < 0.2 ? missing : rand(1:100) for _ in 1:nrows, _ in 1:ncols]

# Deixe a última coluna sem missing
for i in 1:nrows
    data[i, end] = rand(1:100)
end

df_big = DataFrame([data[:,i] for i in 1:ncols], Symbol.(colnames))

MissingPatterns.plotmissing(df_big)