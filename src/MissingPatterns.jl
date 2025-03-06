module MissingPatterns

using Plots

export plotmissing

function plotmissing(df; plot_size=(1000, 800), orientation::Symbol=:vertical, dpi::Int=100, color_missing=:grey10, color_present=:white, line_color=:white, line_width=1, tick_step::Int=5)
    missing_values = Matrix{Bool}(ismissing.(df))

    # Transpõe a matriz se a orientação for horizontal
    if orientation == :horizontal
        missing_values = permutedims(missing_values)  # Transpõe a matriz
        plot_size = reverse(plot_size)
        x_ticks = (1:tick_step:size(missing_values, 2), 1:tick_step:size(missing_values, 2))  # Ticks das linhas no eixo x
        y_ticks = (1:size(missing_values, 1), names(df))  # Ticks das colunas no eixo y (nomes das colunas originais)
        x_label = ""
        y_label = ""
    else
        x_ticks = (1:size(missing_values, 2), names(df))  # Ticks das colunas no eixo x (nomes das colunas)
        y_ticks = (1:tick_step:size(missing_values, 1), 1:tick_step:size(missing_values, 1))  # Ticks das linhas no eixo y
        x_label = ""
        y_label = ""
    end

    p = heatmap(missing_values, 
                xlabel=x_label, ylabel=y_label, 
                title="Missing Patterns", 
                colorbar=false,
                color=cgrad([color_missing, color_present]),
                xticks=x_ticks,
                yticks=y_ticks,
                rotation=90,
                formatter=:plain,
                size=plot_size,
                dpi=dpi)

    # Adiciona linhas verticais ou horizontais dependendo da orientação
    if orientation == :vertical
        for x in 1.5:1:(size(missing_values, 2) - 0.5)
            vline!([x], linecolor=line_color, linewidth=line_width, label="")
        end
    else
        for y in 1.5:1:(size(missing_values, 1) - 0.5)
            hline!([y], linecolor=line_color, linewidth=line_width, label="")
        end
    end

    return p
end

end # module