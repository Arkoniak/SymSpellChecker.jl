#####################################
# Warning - misc stuff, not for usage

using Revise
using DataFrames
using CSV
using BenchmarkTools
using SymSpellChecker
using Profile
using ProfileView
using Logging
using DataVoyager

dfcs = CSV.read(joinpath(@__DIR__, "original_bench.csv"))
dfjl = CSV.read(joinpath(@__DIR__, "bench.csv"))

insertcols!(dfjl, 1, :implementation => "Julia")

df = vcat(dfcs, dfjl)

CSV.write("/home/skoffer/Projects/BabySteps/Spellcheck/benches.csv", df)

v = Voyager(df)

v = Voyager(df[df.dict_name .== "30k", :])

###########################################


df = CSV.read(joinpath(@__DIR__, "words.csv"))
df = sort(df, :med_val, rev = true)
@show head(df)

word = "preard" # Why is it so slow???

ASSETS_PATH = joinpath(@__DIR__, "..", "..", "assets")
# ASSETS_PATH = "/home/skoffer/.julia/dev/SymSpellChecker/assets/"

dicts = [
    joinpath(ASSETS_PATH, "frequency_dictionary_en_30_000.txt"),
    joinpath(ASSETS_PATH, "frequency_dictionary_en_82_765.txt"),
    joinpath(ASSETS_PATH, "frequency_dictionary_en_500_000.txt"),
]

prefix_length = 5
max_edit = 2

# df = DataFrame(word = String[], min_val = Float64[], med_val = Float64[], avg_val = Float64[])
const d = SymSpell(dicts[1], max_dictionary_edit_distance = max_edit, prefix_length = prefix_length)

lookup(d, word, verbosity = SymSpellChecker.VerbosityCLOSEST)

@btime lookup($d, $word, verbosity = SymSpellChecker.VerbosityCLOSEST)

@profview (for _ in 1:1000; lookup(d, word, verbosity = SymSpellChecker.VerbosityCLOSEST); end)

@code_warntype lookup(d, word, false, nothing, false, SymSpellChecker.VerbosityCLOSEST, max_edit)

disable_logging(LogLevel(-100000))
begin
    io = open(joinpath(@__DIR__, "log.txt"), "w")
    logger = SimpleLogger(io)
    global_logger(logger)
    lookup(d, word, false, nothing, false, SymSpellChecker.VerbosityCLOSEST, max_edit)
    flush(io)
end

disable_logging(Logging.Debug)


cnt = [2550, 1098, 348]
lookup(d, word, false, nothing, false, SymSpellChecker.VerbosityCLOSEST, max_edit)

@profview lookup(d, word, false, nothing, false, SymSpellChecker.VerbosityCLOSEST, max_edit)
@profview (for _ in 1:100; lookup(d, word, false, nothing, false, SymSpellChecker.VerbosityCLOSEST, max_edit); end)
length(d.deletes["prear"])
d.words[d.deletes["prear"]]

length(d.deletes["rear"])

hashset1 = Set()
candidates = String[]
candidate = "prear"
SymSpellChecker.add_edits!(hashset1, candidates, candidate, length(candidate))
l = length(candidates)
for i in 1:l
    SymSpellChecker.add_edits!(hashset1, candidates, candidates[i], length(candidates[i]))
end
pushfirst!(candidates, "prear")

for word in candidates
    @show length(d.deletes[word])
end

sum(length(d.deletes[word]) for word in candidates)


d.words[d.deletes[candidates[1]][1]][1]
cnt = [0, 0, 0]

let suggestion_len = d.words[d.deletes[candidates[2]][1]][3], phrase_len = length(word),
    suggestion = d.words[d.deletes[candidates[2]][1]][1], candidate_len = length(candidates[2]),
    candidate = candidates[2]
    @show suggestion_len, candidate_len
    @show suggestion, candidate
    @btime $suggestion_len > $prefix_length ? $prefix_length : $suggestion_len
    SymSpellChecker.light_filter(cnt, suggestion, candidates,
        phrase_len, prefix_length, suggestion_len, candidate_len,
        2, d.prefix_length)
    @btime SymSpellChecker.light_filter($cnt, $suggestion, $candidates,
        $phrase_len, $prefix_length, $suggestion_len, $candidate_len,
        2, $d.prefix_length)
    # @code_typed SymSpellChecker.light_filter(cnt, suggestion, candidates,
    #     phrase_len, prefix_length, suggestion_len, candidate_len,
    #     2, d.prefix_length)
end


d

@btime SymSpellChecker.light_filter($cnt, $d.words[$d.deletes[$candidates[2]][1]][1], $candidates[2],
length($word), $prefix_length, $d.words[$d.deletes[$candidates[2]][1]][3], length($candidates[2]),
2, $d.prefix_length)

@code_warntype SymSpellChecker.light_filter(cnt, d.words[d.deletes[candidates[2]][1]][1], candidates[2],
length(word), prefix_length, d.words[d.deletes[candidates[2]][1]][3], length(candidates[2]),
2, d.prefix_length)


phrase_len = length(candidates[2])
suggestion_len = d.words[d.deletes[candidates[2]][1]][3]
max_edit_distance_2 = 2

@btime $phrase_len - $suggestion_len > $max_edit_distance_2

function f1(phrase_len, suggestion_len, candidate_len,
        max_edit_distance_2, prefix_length, phrase_prefix_len)
    phrase_len - suggestion_len > max_edit_distance_2 && return false
    suggestion_len - phrase_len > max_edit_distance_2 && return false
    suggestion_len < candidate_len && return false

    suggestion_prefix_len = suggestion_len > prefix_length ? prefix_length : suggestion_len
    if (suggestion_prefix_len > phrase_prefix_len) &&
        (suggestion_prefix_len - candidate_len > max_edit_distance_2)
        return false
    end
    true
end

let suggestion_len = d.words[d.deletes[candidates[2]][1]][3], phrase_len = length(word),
    suggestion = d.words[d.deletes[candidates[2]][1]][1], candidate_len = length(candidates[2]),
    candidate = candidates[2]
    @btime f1($phrase_len, $suggestion_len, $candidate_len,
            2, $prefix_length, $prefix_length)
end

length(word)

function light_filter2(cnt, suggestion, candidate,
        phrase_len, phrase_prefix_len, suggestion_len, candidate_len,
        max_edit_distance_2, prefix_length)
    # cnt[1] += 1
    # phrase and suggestion lengths
    # diff > allowed/current best distance
    # if abs(suggestion_len - phrase_len) > max_edit_distance_2 ||
    #     # suggestion must be for a different delete
    #     # string, in same bin only because of hash
    #     # collision
    #     (suggestion_len < candidate_len) ||
    #     # if suggestion len = delete len, then it
    #     # either equals delete or is in same bin
    #     # only because of hash collision
    #     (suggestion_len == candidate_len && suggestion != candidate)
    #     continue
    # end
    abs(phrase_len - suggestion_len) > max_edit_distance_2 && return false
    suggestion_len < candidate_len && return false
    # suggestion_len == candidate_len && suggestion != candidate && return false

    # suggestion_prefix_len = min(suggestion_len, prefix_length)
    # suggestion_prefix_len = suggestion_len
    # suggestion_prefix_len = suggestion_len > prefix_length ? prefix_length : suggestion_len

    suggestion_len > phrase_prefix_len && return false
    # ((min(suggestion_len, prefix_length) > phrase_prefix_len) &
    #     (min(suggestion_len, prefix_length) - candidate_len > max_edit_distance_2)) &&
    #     return false

    # True Damerau-Levenshtein Edit Distance: adjust
    # distance, if both distances>0
    # We allow simultaneous edits (deletes) of
    # max_edit_distance on on both the dictionary and
    # the phrase term. For replaces and adjacent
    # transposes the resulting edit distance stays
    # <= max_edit_distance. For inserts and deletes the
    # resulting edit distance might exceed
    # max_edit_distance. To prevent suggestions of a
    # higher edit distance, we need to calculate the
    # resulting edit distance, if there are
    # simultaneous edits on both sides.
    # Example: (bank==bnak and bank==bink, but
    # bank!=kanb and bank!=xban and bank!=baxn for
    # max_edit_distance=1). Two deletes on each side of
    # a pair makes them all equal, but the first two
    # pairs have edit distance=1, the others edit
    # distance=2.
    #
    # if candidate_len == 0
    #     # suggestions which have no common chars with
    #     # phrase (phrase_len<=max_edit_distance &&
    #     # suggestion_len<=max_edit_distance)
    #
    #     distance = max(phrase_len, suggestion_len)
    #     distance > max_edit_distance_2 && return false
    # end

    # suggestion_id in considered_suggestions && return false
    true
end

function z(cnt, suggestion, candidate,
        phrase_len, phrase_prefix_len, suggestion_len, candidate_len,
        max_edit_distance_2, prefix_length)
    true
end

function f2(d, candidates)
    phrase_len = 6
    cnt = [0, 0, 0]
    res = true
    for candidate in candidates
        candidate_len = length(candidate)
        for sugg in d.words[d.deletes[candidate]]
            suggestion = sugg[1]
            suggestion_len = sugg[3]

            # z(cnt, suggestion, candidate,
            #     phrase_len, prefix_length, suggestion_len, candidate_len,
            #     2, d.prefix_length)

            res = res ⊻ SymSpellChecker.light_filter(cnt, suggestion, candidate,
                phrase_len, d.prefix_length, suggestion_len, candidate_len,
                2, d.prefix_length)
        end
    end
end

f2(d, candidates)

@btime f2($d, $candidates)
@code_warntype f2(d, candidates)

function f3(d, med_res)
    phrase = "preard"
    phrase_len = length(phrase)
    cnt = [0, 0, 0]
    res = true
    for (suggestion, candidate, suggestion_len, candidate_len) in med_res
        SymSpellChecker.medium_filter(cnt, suggestion, candidate, phrase,
            phrase_len, suggestion_len, candidate_len,
            2, d.prefix_length,
            SymSpellChecker.VerbosityCLOSEST) && continue

        # res = res ⊻ SymSpellChecker.light_filter(cnt, suggestion, candidate,
        #     phrase_len, d.prefix_length, suggestion_len, candidate_len,
        #     2, d.prefix_length)
    end
end


@btime f3($d, $med_res)
med_res = Tuple{String, String}[]
med_res = map(x -> (string(x[1]), string(x[2]), length(x[1]), length(x[2])), split.(readlines(joinpath(@__DIR__, "medium_suggestions.csv")), ","))

med_res
