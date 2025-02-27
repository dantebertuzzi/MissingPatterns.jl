using MissingPatterns
using Documenter

DocMeta.setdocmeta!(MissingPatterns, :DocTestSetup, :(using MissingPatterns); recursive=true)

makedocs(;
    modules=[MissingPatterns],
    authors="Dante Bertuzzi",
    repo="https://github.com/dantebertuzzi/MissingPatterns.jl/blob/{commit}{path}#{line}",
    sitename="MissingPatterns.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://dantebertuzzi.github.io/MissingPatterns.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/dantebertuzzi/MissingPatterns.jl",
)
