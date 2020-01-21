module BenchLookup
using BenchmarkTools
using SymSpell
using SymSpell: VerbosityALL

suite = BenchmarkGroup()

d = Dictionary()

push!(d, "a", 5)
push!(d, "bc", 2)
s = "abc"

suite["simple_lookup"] = @benchmarkable lookup($d, $s, max_edit_distance = 1)

d2 = Dictionary(joinpath(@__DIR__, "..", "assets", "frequency_dictionary_en_82_765.txt"))
s1 = "quintesestnial"
s2 = "goophr"

suite[s1] = @benchmarkable lookup($d2, $s1)
suite[s2] = @benchmarkable lookup($d2, $s2, verbosity = VerbosityALL)

end

BenchLookup.suite
