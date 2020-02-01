module TestBigLookup

include("preamble.jl")

using SymSpellChecker: SuggestItem, Verbosity,
    VerbosityALL, VerbosityTOP, VerbosityCLOSEST

ASSETS_PATH = joinpath(@__DIR__, "..", "assets")

function load_noisy()
    map(readlines(joinpath(ASSETS_PATH, "noisy_query_en_1000.txt"))) do x
        String(strip(split(x)[1]))
    end
end

function mix(d, data, verbosity)
    sum(length(lookup(d, word, verbosity = verbosity)) for word in data)
end

dicts = [
    joinpath(ASSETS_PATH, "frequency_dictionary_en_30_000.txt"),
    joinpath(ASSETS_PATH, "frequency_dictionary_en_82_765.txt"),
    joinpath(ASSETS_PATH, "frequency_dictionary_en_500_000.txt"),
]

query1k = load_noisy()

@testset "30k edit distance 1 prefix 5 verbosity all" begin
    d = SymSpell(dicts[1], max_dictionary_edit_distance = 1, prefix_length = 5)
    @test length(lookup(d, "hockie", verbosity = SymSpellChecker.VerbosityALL)) == 0
    @test mix(d, query1k, SymSpellChecker.VerbosityALL) == 5371
end

@testset "30k edit distance 3 prefix 5 verbosity all" begin
    d = SymSpell(dicts[1], max_dictionary_edit_distance = 3, prefix_length = 5)
    @test length(lookup(d, "hockie", verbosity = SymSpellChecker.VerbosityALL)) == 88
    @test mix(d, query1k, SymSpellChecker.VerbosityALL) == 555555
end
end # module
