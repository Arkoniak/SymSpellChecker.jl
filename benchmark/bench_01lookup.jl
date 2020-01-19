module BenchLookup
using BenchmarkTools
using SymSpell: get_opcodes, transfer_casing_for_similar_text

suite = BenchmarkGroup()
s1 = "qabxcd"
s2 = "abycdf"
suite["opcodes"] = @benchmarkable get_opcodes($s1, $s2)

text_w_casing = "Haaw is the weeather in New York?"
text_wo_casing = "how is the weather in new york?"
suite["transfer_casing"] = @benchmarkable transfer_casing_for_similar_text($text_w_casing, $text_wo_casing)

end
BenchLookup.suite
