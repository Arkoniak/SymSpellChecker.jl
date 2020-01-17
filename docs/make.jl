using Documenter, SymSpell

makedocs(;
    modules=[SymSpell],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/Arkoniak/SymSpell.jl/blob/{commit}{path}#L{line}",
    sitename="SymSpell.jl",
    authors="Andrey Oskin",
    assets=String[],
)

deploydocs(;
    repo="github.com/Arkoniak/SymSpell.jl",
)
