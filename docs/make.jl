using Documenter, SymSpellChecker

makedocs(;
    modules=[SymSpellChecker],
    authors="Andrey Oskin",
    repo="https://github.com/Arkoniak/SymSpellChecker.jl/blob/{commit}{path}#L{line}",
    sitename="SymSpellChecker.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Arkoniak.github.io/SymSpellChecker.jl",
        siteurl="https://github.com/Arkoniak/SymSpellChecker.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Arkoniak/SymSpellChecker.jl",
)
