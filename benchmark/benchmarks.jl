using BenchmarkTools

const SUITE = BenchmarkGroup()
SUITE["lookup"]= BenchmarkGroup(["match", "opcodes"])

s1 = "qabxcd"
s2 = "abycdf"
SUITE["lookup"]["opcodes"] = @benchmarkable SymSpell.get_opcodes($s1, $s2)
