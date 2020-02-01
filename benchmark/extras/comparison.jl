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

function mix(d, data, verbosity)
    sum(length(lookup(d, word, verbosity = verbosity)) for word in data)
end

df = DataFrame(max_edit = Int[], prefix_length = Int[], dict_name = String[], verbosity = String[], type = String[],
    res = Int[], min_val = Float64[], med_val = Float64[], avg_val = Float64[])

for max_edit in 1:3
    for prefix_length in 5:7
        for (dict_path, dict_name) in zip(dicts, dict_names)
            d = SymSpell(dict_path, max_dictionary_edit_distance = max_edit, prefix_length = prefix_length)
            for verbosity in [VerbosityTOP, VerbosityCLOSEST, VerbosityALL]
                verb_name = verbosity == VerbosityTOP ? "top" : verbosity == VerbosityCLOSEST ? "closest" : "all"
                b = @benchmark lookup($d, $"different", verbosity = $verbosity)
                println("max_edit: $max_edit\tprefix_length: $prefix_length\tdict: $dict_name\tverbosity: $verbosity\ttype: exact\tmin: $(minimum(b.times/1000_000))\tmed: $(median(b.times/1000_000))\tavg: $(mean(b.times/1000_000))")
                res = length(lookup(d, "different", verbosity = verbosity))

                push!(df, (max_edit, prefix_length, dict_name, verb_name, "exact", res,
                    minimum(b.times/1000_000), median(b.times/1000_000), mean(b.times/1000_000)))

                b = @benchmark lookup($d, $"hockie", verbosity = $verbosity)
                println("max_edit: $max_edit\tprefix_length: $prefix_length\tdict: $dict_name\tverbosity: $verbosity\ttype: non-exact\tmin: $(minimum(b.times/1000_000))\tmed: $(median(b.times/1000_000))\tavg: $(mean(b.times/1000_000))")
                res = length(lookup(d, "hockie", verbosity = verbosity))

                push!(df, (max_edit, prefix_length, dict_name, verb_name, "non-exact", res,
                    minimum(b.times/1000_000), median(b.times/1000_000), mean(b.times/1000_000)))

                b = @benchmark mix($d, $query1k, $verbosity)
                println("max_edit: $max_edit\tprefix_length: $prefix_length\tdict: $dict_name\tverbosity: $verbosity\ttype: mix\tmin: $(minimum(b.times/1000_000_000))\tmed: $(median(b.times/1000_000_000))\tavg: $(mean(b.times/1000_000_000))")
                res = mix(d, query1k, verbosity)

                push!(df, (max_edit, prefix_length, dict_name, verb_name, "mix", res,
                    minimum(b.times/1000_000_000), median(b.times/1000_000_000), mean(b.times/1000_000_000)))
            end
        end
    end
end

CSV.write(joinpath(@__DIR__, "bench.csv"), df)
