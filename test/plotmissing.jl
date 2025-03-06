using DataFrames
using MissingPatterns
using Random

# Configuração para reproduzibilidade
Random.seed!(123)

# Criando um DataFrame com 10.000 linhas e 5 colunas
n_rows = 10_000
n_cols = 5
df = DataFrame(rand(n_rows, n_cols), :auto)

# Adicionando valores ausentes aleatoriamente (20% de missing)
for col in names(df)
    df[!, col] = allowmissing(df[!, col])
    df[rand(1:n_rows, Int(round(0.2 * n_rows))), col] .= missing
end

# Visualizando os padrões de missing
plotmissing(df, orientation=:vertical, tick_step=1000)  # Vertical

