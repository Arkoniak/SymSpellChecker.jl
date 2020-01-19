using SymSpell
using BenchmarkTools
using Statistics

SUITE = BenchmarkGroup()
SUITE["lookup"]= BenchmarkGroup(["match", "opcodes"])

s1 = "qabxcd"
s2 = "abycdf"
SUITE["lookup"]["opcodes"] = @benchmarkable SymSpell.get_opcodes($s1, $s2)

tune!(SUITE)
results = run(SUITE, verbose = true)

m1 = median(results["lookup"])
#############
# After modifications
m2 = median(run(SUITE["lookup"]))

judge(m1, m2)
