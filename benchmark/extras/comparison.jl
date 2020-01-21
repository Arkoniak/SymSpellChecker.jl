using BenchmarkTools
using SymSpell
using Statistics
using ProfileView

function load_noisy()
    map(readlines(joinpath(@__DIR__, "noisy_query_en_1000.txt"))) do x
        String(split(x)[1])
    end
end

dicts = [
    joinpath(@__DIR__, "frequency_dictionary_en_30_000.txt"),
    joinpath(@__DIR__, "..", "..", "assets", "frequency_dictionary_en_82_765.txt"),
    joinpath(@__DIR__, "frequency_dictionary_en_500_000.txt"),
]

query1k = load_noisy()

function mix(d, data, verbosity)
    sum(length(lookup(d, word, verbosity = verbosity)) for word in data)
end

max_edit = 1
prefix_length = 5

d = Dictionary(dicts[1], max_dictionary_edit_distance = max_edit, prefix_length = prefix_length)

lookup(d, "different", verbosity = SymSpell.VerbosityTOP)

lookup(d, "hockie", verbosity = SymSpell.VerbosityTOP)

bres = @benchmark lookup($d, "different", verbosity = $SymSpell.VerbosityTOP)
0.0006489107142857143
median(bres.times)/1000/1000

bres = @benchmark lookup($d, "hockie", verbosity = $SymSpell.VerbosityTOP)
0.0111
median(bres.times)/1000/1000

bres = @benchmark mix($d, $query1k, $SymSpell.VerbosityTOP)
0.139868706
median(bres.times)/1000/1000/1000
sum(length(lookup(d, word, verbosity = SymSpell.VerbosityTOP)) for word in query1k)

Base.summarysize(d)/1024/1024

word = "années"

word[1:1]*word[3:3]
collect(word)

chr2ind(word, 1)
word[nextind(word, 2):nextind(word, 2)]

word = "что"
let i = 0
    while i < lastindex(word)
        println(word[1:i] * word[nextind(word, nextind(word, i)):end])
        i = nextind(word, i)
    end
end

function conv_idx(word, i)
    k = 0
    for j in 1:i
        k = nextind(word, k)
    end
    k
end

conv_idx(word, 3)
nextind(word)
word[3]
nextind(word, 1)
word[4:end]
lastindex(word)
word[nextind(word, 1)]


##################
# @profview mix(d, query1k, SymSpell.VerbosityALL)

@code_warntype lookup(d, "hockie")
