module MissingPatterns

using Printf
using Statistics
using DataFrames

export plotmissing

"""
plotmissing(df; char_missing='█', char_present='░', char_width=5, max_rows=50, max_cols=20)

Exibe no terminal um "heatmap" textual mostrando padrões de valores faltantes em um DataFrame.
Se o dataset for maior que os limites, agrupa múltiplas linhas/colunas em uma única célula.

# Argumentos
- `df`: DataFrame de entrada.
- `char_missing`: Caractere para valores faltantes.
- `char_present`: Caractere para valores presentes.
- `char_width`: Largura do caractere para exibição.
- `max_rows`: Número máximo de linhas a exibir (padrão: 50).
- `max_cols`: Número máximo de colunas a exibir (padrão: 20).

# Retorno
- Nada. O plot é impresso no terminal.
"""
function plotmissing(df; char_missing::Char='█', char_present::Char='░', char_width::Int=5, max_rows::Int=50, max_cols::Int=20)
    
    # Função para agrupar dados em blocos
    function compress_data(data::Matrix{Bool}, target_rows::Int, target_cols::Int)
        orig_rows, orig_cols = size(data)
        
        # Calcula quantas linhas/colunas originais cada célula representa
        rows_per_cell = ceil(Int, orig_rows / target_rows)
        cols_per_cell = ceil(Int, orig_cols / target_cols)
        
        # Calcula o tamanho final da matriz comprimida
        compressed_rows = ceil(Int, orig_rows / rows_per_cell)
        compressed_cols = ceil(Int, orig_cols / cols_per_cell)
        
        compressed = Matrix{Float64}(undef, compressed_rows, compressed_cols)
        
        for i in 1:compressed_rows
            for j in 1:compressed_cols
                # Define os índices do bloco original
                row_start = (i-1) * rows_per_cell + 1
                row_end = min(i * rows_per_cell, orig_rows)
                col_start = (j-1) * cols_per_cell + 1
                col_end = min(j * cols_per_cell, orig_cols)
                
                # Calcula a proporção de missing no bloco
                block = data[row_start:row_end, col_start:col_end]
                compressed[i,j] = sum(block) / length(block)
            end
        end
        
        return compressed, rows_per_cell, cols_per_cell
    end
    
    # Função para converter proporção em caractere visual
    function prop_to_char(prop::Float64, char_missing::Char, char_present::Char)
        if prop == 0.0
            return char_present
        elseif prop == 1.0
            return char_missing
        elseif prop <= 0.05
            return '·'  # Muito poucos missing (1-5%)
        elseif prop <= 0.15
            return '░'  # Poucos missing (5-15%)
        elseif prop <= 0.30
            return '▒'  # Médio missing (15-30%)
        elseif prop <= 0.50
            return '▓'  # Muitos missing (30-50%)
        elseif prop <= 0.75
            return '█'  # Muitos missing (50-75%)
        else
            return '█'  # Quase todos missing (>75%)
        end
    end
    
    original_size = size(df)
    missing_values = Matrix{Bool}(ismissing.(df))
    nrows, ncols = size(missing_values)
    colnames = names(df)
    
    # Verifica se o DataFrame está vazio
    if nrows == 0 || ncols == 0
        println("DataFrame vazio - nada para exibir")
        return nothing
    end
    
    # Determina se precisa comprimir
    needs_compression = nrows > max_rows || ncols > max_cols
    
    if needs_compression
        target_rows = min(nrows, max_rows)
        target_cols = min(ncols, max_cols)
        
        compressed_data, rows_per_cell, cols_per_cell = compress_data(missing_values, target_rows, target_cols)
        display_rows, display_cols = size(compressed_data)
        
        # Cria nomes de colunas comprimidos
        if ncols > max_cols
            compressed_colnames = String[]
            for j in 1:display_cols
                col_start = (j-1) * cols_per_cell + 1
                col_end = min(j * cols_per_cell, ncols)
                if col_start == col_end
                    push!(compressed_colnames, string(colnames[col_start]))
                else
                    push!(compressed_colnames, "$(col_start)-$(col_end)")
                end
            end
        else
            compressed_colnames = string.(colnames)
        end
        

    else
        compressed_data = Float64.(missing_values)
        display_rows, display_cols = nrows, ncols
        compressed_colnames = string.(colnames)
        rows_per_cell = cols_per_cell = 1
    end
    
    # Calcula largura das colunas (agora com limite de 4 chars + "...")
    max_display_name = 7  # 4 chars + "..." = máximo 7 caracteres
    colwidth = max(char_width + 2, max_display_name + 2, 6)
    
    # Top border
    print("┏")
    print(join([repeat("━", colwidth) for _ in 1:display_cols], "┳"))
    println("┓")

    # Porcentagem de missing por coluna
    print("┃")
    for j in 1:display_cols
        if needs_compression
            # Para dados comprimidos, calcula a média das proporções
            col_start = (j-1) * cols_per_cell + 1
            col_end = min(j * cols_per_cell, ncols)
            perc = 100 * mean([count(missing_values[:,k]) / nrows for k in col_start:col_end])
        else
            perc = 100 * mean(compressed_data[:,j])
        end
        
        perc_str = @sprintf("%3d%%", round(Int, perc))
        pad_total = colwidth - length(perc_str)
        pad_left = div(pad_total, 2)
        pad_right = pad_total - pad_left
        print(repeat(" ", pad_left), perc_str, repeat(" ", pad_right))
        print("┃")
    end
    println()

    # Header separator
    print("┣")
    print(join([repeat("━", colwidth) for _ in 1:display_cols], "╋"))
    println("┫")

    # Cabeçalho das colunas
    print("┃")
    for j in 1:display_cols
        name = compressed_colnames[j]
        
        # Limita nome a 4 caracteres + "..." se necessário
        if length(name) > 4
            display_name = name[1:4] * "..."
        else
            display_name = name
        end
        
        # Garante que não exceda a largura da coluna
        if length(display_name) > colwidth - 2
            display_name = display_name[1:colwidth-2]
        end
        
        pad_total = colwidth - length(display_name)
        pad_left = div(pad_total, 2)
        pad_right = pad_total - pad_left
        print(repeat(" ", pad_left), display_name, repeat(" ", pad_right))
        print("┃")
    end
    println()

    # Middle separator
    print("┣")
    print(join([repeat("━", colwidth) for _ in 1:display_cols], "╋"))
    println("┫")

    # Linhas do heatmap
    for i in 1:display_rows
        print("┃")
        for j in 1:display_cols
            if needs_compression
                cellchar = repeat(prop_to_char(compressed_data[i,j], char_missing, char_present), char_width)
            else
                cellchar = repeat(compressed_data[i,j] == 1.0 ? char_missing : char_present, char_width)
            end
            
            pad_total = colwidth - length(cellchar)
            pad_left = div(pad_total, 2)
            pad_right = pad_total - pad_left
            print(repeat(" ", pad_left), cellchar, repeat(" ", pad_right))
            print("┃")
        end
        println()
    end

    # Bottom border
    print("┗")
    print(join([repeat("━", colwidth) for _ in 1:display_cols], "┻"))
    println("┛")

    # Summary estatístico no estilo BenchmarkTools
    total_cells = original_size[1] * original_size[2]
    missing_count = sum(Matrix{Bool}(ismissing.(df)))
    present_count = total_cells - missing_count
    missing_pct = 100 * missing_count / total_cells
    present_pct = 100 - missing_pct
    
    # Códigos de cor ANSI
    blue = "\033[34m"
    orange = "\033[38;5;208m"
    reset = "\033[0m"
    
    println()
    println("MissingPatterns.Analysis: $(blue)$(original_size[1])$(reset) × $(blue)$(original_size[2])$(reset) DataFrame")
    
    if needs_compression
        println(" Compression: $(blue)$(original_size[1])$(reset)×$(blue)$(original_size[2])$(reset) → $(blue)$(display_rows)$(reset)×$(blue)$(display_cols)$(reset) cells  ┊ Ratio: $(blue)$(rows_per_cell)$(reset)×$(blue)$(cols_per_cell)$(reset) per cell")
        if rows_per_cell > 100
            println(" Sensitivity: Enhanced for large datasets (·=1-5%, ░=5-15%, ▒=15-30%, ▓=30-50%, █=50%+)")
        end
    else
        println(" Compression: No compression needed                    ┊ Ratio: $(blue)1$(reset)×$(blue)1$(reset) per cell")
    end
    
    println(" Missing (count):  $(lpad("$(blue)$(missing_count)$(reset)", 18))               ┊ Missing ($(orange)%$(reset)):  $(lpad("$(blue)$(@sprintf("%.2f", missing_pct))$(reset)$(orange)%$(reset)", 16))")
    println(" Present (count):  $(lpad("$(blue)$(present_count)$(reset)", 18))               ┊ Present ($(orange)%$(reset)):  $(lpad("$(blue)$(@sprintf("%.2f", present_pct))$(reset)$(orange)%$(reset)", 16))")
    
    # Barra de progresso visual
    bar_width = 40
    missing_bars = round(Int, bar_width * missing_pct / 100)
    present_bars = bar_width - missing_bars
    
    print(" Progress Bar:     ")
    print("$(blue)[$(reset)")
    if missing_bars > 0
        print("$(orange)$(repeat("█", missing_bars))$(reset)")
    end
    if present_bars > 0
        print("$(blue)$(repeat("█", present_bars))$(reset)")
    end
    println("$(blue)]$(reset)")
end

end # module