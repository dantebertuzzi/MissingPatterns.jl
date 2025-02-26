using MatricialMissing
using Documenter

DocMeta.setdocmeta!(MatricialMissing, :DocTestSetup, :(using MatricialMissing); recursive=true)

makedocs(;
    modules=[MatricialMissing],
    authors="Dante Bertuzzi",
    repo="https://github.com/dantebertuzzi/MatricialMissing.jl/blob/{commit}{path}#{line}",
    sitename="MatricialMissing.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://dantebertuzzi.github.io/MatricialMissing.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/dantebertuzzi/MatricialMissing.jl",
)
