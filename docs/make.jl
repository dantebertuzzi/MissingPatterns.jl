using MissingPatterns
using Documenter
import Documenter.Remotes

DocMeta.setdocmeta!(MissingPatterns, :DocTestSetup, :(using MissingPatterns); recursive=true)

makedocs(;
    modules=[MissingPatterns],
    authors="Dante Bertuzzi",
    sitename="MissingPatterns.jl",
    repo=Remotes.GitHub("dantebertuzzi", "MissingPatterns.jl"),
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://dantebertuzzi.github.io/MissingPatterns.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Heatmaps" => "heatmap.md",
        "Diagnostics" => "diagnostics.md",
        "Data API" => "data.md",
        "Export and output" => "export.md",
        "Public API" => "api.md",
        "Internals" => "internals.md",
    ],
)

deploydocs(;
    repo="github.com/dantebertuzzi/MissingPatterns.jl",
    devbranch="main",
    push_preview=true,
)
