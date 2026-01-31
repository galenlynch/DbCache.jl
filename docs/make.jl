using DbCache
using Documenter

DocMeta.setdocmeta!(DbCache, :DocTestSetup, :(using DbCache); recursive=true)

makedocs(;
    modules=[DbCache],
    authors="Galen Lynch <galen@galenlynch.com>",
    sitename="DbCache.jl",
    format=Documenter.HTML(;
        canonical="https://galenlynch.github.io/DbCache.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/galenlynch/DbCache.jl",
    devbranch="main",
)
