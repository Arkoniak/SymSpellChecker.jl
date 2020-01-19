using SymSpell
using BenchmarkTools
using Statistics
using Revise

cd(@__DIR__)

SUITE = BenchmarkGroup()
SUITE["lookup"]= BenchmarkGroup(["match", "opcodes"])

s1 = "qabxcd"
s2 = "abycdf"
SUITE["lookup"]["opcodes"] = @benchmarkable SymSpell.get_opcodes($s1, $s2)

text_w_casing = "Haaw is the weeather in New York?"
text_wo_casing = "how is the weather in new york?"
SUITE["lookup"]["transfer_casing"] = @benchmarkable SymSpell.transfer_casing_for_similar_text($text_w_casing, $text_wo_casing)

# First time only
tune!(SUITE)
BenchmarkTools.save("params.json", params(SUITE))
# results = run(SUITE, verbose = true)
results = run(SUITE)
BenchmarkTools.save("results1.json", results)

# Second time (different implementation)
res1 = BenchmarkTools.load("results1.json")[1]

loadparams!(SUITE, BenchmarkTools.load("params.json")[1], :evals, :samples)
res2 = run(SUITE)

judge(median(res1), median(res2))


#####
# PkgBenchmark

using PkgBenchmark
import SymSpell
br = benchmarkpkg("SymSpell")

cd(@__DIR__)
PkgBenchmark.export_markdown("SomeTest2.md", br)
