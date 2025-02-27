using DataFrames, MissingPatterns, Random

# Configurando a semente para reprodutibilidade
Random.seed!(123)

# Criando um DataFrame com mais dados e valores faltantes
n = 100  # Número de linhas
df = DataFrame(
    A = rand([1, 2, 3, missing], n),
    B = rand([10, 20, 30, 40, missing], n),
    C = rand([100, 200, 300, missing], n),
    D = rand([missing, 5.5, 6.5, 7.5, 8.5], n),
    E = rand([missing, "X", "Y", "Z"], n)
)

# Plotando com orientação horizontal
plotmissing(df, orientation=:horizontal, dpi=150, color_missing=:red, color_present=:green, line_color=:blue, line_width=2)

# Plotando com orientação vertical (padrão)
plotmissing(df, dpi=900)

