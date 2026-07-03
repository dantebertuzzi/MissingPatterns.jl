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
    ],
)

deploydocs(;
    repo="github.com/dantebertuzzi/MissingPatterns.jl",
    push_preview=true,
)
