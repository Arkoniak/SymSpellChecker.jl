using BenchmarkTools
using SymSpellChecker
using SymSpellChecker: VerbosityALL, VerbosityTOP, VerbosityCLOSEST
using Statistics
using CSV
using DataFrames

ASSETS_PATH = joinpath(@__DIR__, "..", "..", "assets")
function load_noisy()
    map(readlines(joinpath(ASSETS_PATH, "noisy_query_en_1000.txt"))) do x
        String(split(x)[1])
    end
end

dicts = [
    joinpath(ASSETS_PATH, "frequency_dictionary_en_30_000.txt"),
    joinpath(ASSETS_PATH, "frequency_dictionary_en_82_765.txt"),
    joinpath(ASSETS_PATH, "frequency_dictionary_en_500_000.txt"),
]

dict_names = ["30k", "82k", "500k"]

query1k = load_noisy()

prefix_length = 5
max_edit = 2

# df = DataFrame(word = String[], min_val = Float64[], med_val = Float64[], avg_val = Float64[])
const d = SymSpell(dicts[1], max_dictionary_edit_distance = max_edit, prefix_length = prefix_length)

open(joinpath(@__DIR__, "words.csv"), "w") do file
    println(file, "word,min_val,med_val,avg_val")
    flush(file)
    for (i, word) in enumerate(query1k)
        bm = @benchmark lookup($d, $word, verbosity = $VerbosityCLOSEST)
        # push!(df, (word, minimum(bm.times/1000_000), median(bm.times/1000_000), mean(bm.times/1000_000)))
        println(file, "$word,$(minimum(bm.times/1000_000)),$(median(bm.times/1000_000)),$(mean(bm.times/1000_000))")
        flush(file)
        if mod(i, 50) == 0
            @show i
        end
    end
end
# sort!(df, :med_val, rev = true)
