using BenchmarkTools
using SymSpell

const SUITE = BenchmarkGroup()
SUITE["lookup"]= BenchmarkGroup(["match", "opcodes"])

s1 = "qabxcd"
s2 = "abycdf"
SUITE["lookup"]["opcodes"] = @benchmarkable SymSpell.get_opcodes($s1, $s2)

text_w_casing = "Haaw is the weeather in New York?"
text_wo_casing = "how is the weather in new york?"
SUITE["lookup"]["transfer_casing"] = @benchmarkable SymSpell.transfer_casing_for_similar_text($text_w_casing, $text_wo_casing)
