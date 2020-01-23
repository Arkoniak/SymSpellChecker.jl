module BenchMixLookup
using BenchmarkTools
using SymSpellChecker
using SymSpellChecker: VerbosityALL, VerbosityCLOSEST

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

suite = BenchmarkGroup()

for edit_distance in 1:3
    for prefix_length in 5:7
        d = SymSpell(dicts[2], max_dictionary_edit_distance = edit_distance, prefix_length = prefix_length)
        suite["mix_lookup_closest_$(edit_distance)_$(prefix_length)"] = @benchmarkable mix($d, $query1k, $VerbosityCLOSEST)
    end
end
end

BenchMixLookup.suite
