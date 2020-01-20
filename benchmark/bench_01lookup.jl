module BenchLookup
using BenchmarkTools
using SymSpell

suite = BenchmarkGroup()
# d = Dictionary()
# update!(d, joinpath(@__DIR__, "..", "assets", "frequency_dictionary_en_82_765.txt"))

d = Dictionary()

push!(d, "a", 5)
push!(d, "bc", 2)
s = "abc"

suite["simple_lookup"] = @benchmarkable lookup($d, $s, max_edit_distance = 1)

end

BenchLookup.suite
