struct SuggestItem{T <: AbstractString}
    term::T
    distance::Int
    count::Int
end

SuggestItem(term::String32, distance::Int, count::Int) = SuggestItem{String}(String(term.s), distance, count)
term(si::SuggestItem) = si.term

Base.:isless(si1::SuggestItem, si2::SuggestItem) = (si1.distance < si2.distance) ||
    ((si1.distance == si2.distance) && (si1.count > si2.count)) ||
    ((si1.distance == si2.distance) && (si1.count == si2.count) && (si1.term < si2.term))


function set_options!(dict::SymSpell; kwargs...)
    for (opt, v) in kwargs
        if opt in fieldnames(LookupOptions)
            setfield!(dict.lookup, opt, v)
        else
            @warn "Lookup option '$opt' is not supported"
        end
    end
end

"""
    lookup(dict, phrase, max_edit_distance, include_unknown, ignore_token, transfer_casing)

Find suggested spellings for a given phrase word.
Parameters
----------
phrase : str
    The word being spell checked.
verbosity : :class:`Verbosity`
    The value controlling the quantity/closeness of the
    returned suggestions.
max_edit_distance : int, optional
    The maximum edit distance between phrase and suggested
    words. Set to :attr:`_max_dictionary_edit_distance` by
    default
include_unknown : bool, optional
    A flag to determine whether to include phrase word in
    suggestions, if no words within edit distance found.
ignore_token : regex pattern, optional
    A regex pattern describing what words/phrases to ignore and
    leave unchanged
transfer_casing : bool, optional
    A flag to determine whether the casing --- i.e., uppercase
    vs lowercase --- should be carried over from `phrase`.
Returns
-------
suggestions : list
    suggestions is a list of :class:`SuggestItem` objects
    representing suggested correct spellings for the phrase
    word, sorted by edit distance, and secondarily by count
    frequency.
Raises
------
ValueError
    If `max_edit_distance` is greater than
    :attr:`_max_dictionary_edit_distance`
"""
function lookup(dict, phrase::S; include_unknown = dict.lookup.include_unknown,
        ignore_token = dict.lookup.ignore_token, transfer_casing = dict.lookup.transfer_casing,
        verbosity::Union{String, Verbosity} = dict.lookup.verbosity,
        max_edit_distance = dict.lookup.max_edit_distance) where {S <: AbstractString}

        if verbosity isa String
            verbosity = verbosity == "top" ? VerbosityTOP : verbosity == "closest" ? VerbosityCLOSEST : VerbosityALL
        end
        lookup(dict, String32(phrase), include_unknown, ignore_token,
            transfer_casing, verbosity, max_edit_distance)
end

Base.:getindex(dict, phrase) = term.(lookup(dict, phrase))

# True Damerau-Levenshtein Edit Distance: adjust distance, if both distances>0
# We allow simultaneous edits (deletes) of max_edit_distance on on both the dictionary and
# the phrase term. For replaces and adjacent transposes the resulting edit distance stays
# <= max_edit_distance. For inserts and deletes the resulting edit distance might exceed
# max_edit_distance. To prevent suggestions of a higher edit distance, we need to calculate the
# resulting edit distance, if there are simultaneous edits on both sides.
# Example: (bank==bnak and bank==bink, but bank!=kanb and bank!=xban and bank!=baxn for
# max_edit_distance=1). Two deletes on each side of a pair makes them all equal, but the first two
# pairs have edit distance=1, the others edit distance=2.
function lookup(dict::SymSpell{T, K}, phrase::String32, include_unknown::Bool, ignore_token,
                transfer_casing::Bool, verbosity::Verbosity,
                max_edit_distance::Int) where {T, K}
    if max_edit_distance > dict.max_dictionary_edit_distance
        throw(ArgumentError("Distance $max_edit_distance larger than dictionary threshold $(dict.max_dictionary_edit_distance)"))
    end

    suggestions = SuggestItem{String}[]

    phrase_original = phrase
    if transfer_casing
        phrase = lowercase(phrase)
    end
    phrase_len = length(phrase)

    early_exit = let phrase = phrase_original, suggestions = suggestions, include_unknown = include_unknown, max_edit_distance = max_edit_distance
        function early_exit()
            if include_unknown && isempty(suggestions)
                push!(suggestions, SuggestItem(phrase, max_edit_distance + 1, 0))
            end
            suggestions
        end
    end

    # early exit - word is too big to possibly match any words
    if phrase_len - max_edit_distance > dict.max_length
        return early_exit()
    end

    # quick look for exact match
    if phrase_original in keys(dict.words_idx)
        push!(suggestions, SuggestItem(phrase, 0, dict.words[dict.words_idx[phrase_original]].count))
        if verbosity != VerbosityALL
            return suggestions
        end
        idx = dict.words_idx[phrase]
    else
        idx = K(0)
    end

    if ignore_token != nothing && occursin(ignore_token, phrase)
        suggestion_cnt = 1
        push!(suggestions, SuggestItem(phrase, 0, suggestion_cnt))
        # early exit - return exact match, unless caller wants all matches
        if verbosity != VerbosityALL
            return early_exit()
        end
    end

    # early termination, if we only want to check if word in
    # dictionary or get its frequency e.g. for word segmentation
    if max_edit_distance == 0
        return early_exit()
    end

    considered_deletes = Set{String}()
    considered_suggestions = Set{K}()

    # we considered the phrase already in the
    # 'phrase in keys(dict.words)' above
    if idx > 0
        push!(considered_suggestions, idx)
    end

    max_edit_distance_2 = max_edit_distance
    candidates = String[]

    # add original prefix
    phrase_prefix_len = min(phrase_len, dict.prefix_length)
    push!(candidates, String(phrase.s[1:phrase_prefix_len]))

    is_first = true

    local v2
    local v0

    while !isempty(candidates)
        candidate = popfirst!(candidates)
        candidate_len = length(candidate)
        len_diff = phrase_prefix_len - candidate_len
        # early termination: if candidate distance is already
        # higher than suggestion distance, than there are no better
        # suggestions to be expected
        if len_diff > max_edit_distance_2
            # skip to next candidate if Verbosity.ALL, look no
            # further if Verbosity.TOP or CLOSEST (candidates are
            # ordered by delete distance, so none are closer than
            # current)
            verbosity == VerbosityALL && continue
            break
        end

        if candidate in keys(dict.deletes)
            for suggestion_id in dict.deletes[candidate]
                @inbounds dict_word = dict.words[suggestion_id]
                suggestion = dict_word.word
                suggestion_len = length(dict_word.word)
                suggestion_cnt = dict_word.count

                !simple_filter(phrase_len, phrase_prefix_len,
                    suggestion_len, candidate_len,
                    max_edit_distance_2, dict.prefix_length) && continue

                # number of edits in prefix == maxeditdistance AND no identical suffix, then
                # editdistance > max_edit_distance and no need for Levenshtein calculation
                # (phraseLen >= prefixLength) && (suggestionLen >= prefixLength)
                if dict.prefix_length - max_edit_distance == candidate_len
                    min_distance = min(phrase_len, suggestion_len) - dict.prefix_length

                    min_distance > 1 &&
                        equal_suffixes(phrase, suggestion, min_distance) && continue
                    if min_distance > 0
                        p1 = phrase_len + 1 - min_distance
                        s1 = suggestion_len + 1 - min_distance
                        @inbounds if phrase[p1] != suggestion[s1]
                            @inbounds (phrase[p1 - 1] != suggestion[s1] || phrase[p1] != suggestion[s1 - 1]) && continue
                        end
                    end
                end

                # DL and considered_suggestions compete with each othere
                # In ALL mode it's usually better to test for already
                # verified suggestions
                if verbosity == VerbosityALL
                    suggestion_id in considered_suggestions && continue
                    push!(considered_suggestions, suggestion_id)
                end
                if is_first
                    v2 = Vector{Int}(undef, phrase_len + max_edit_distance)
                    v0 = similar(v2)
                    is_first = false
                end
                distance = evaluate!(phrase, suggestion, max_edit_distance_2, v0, v2)
                distance > max_edit_distance_2 && continue

                if verbosity != VerbosityALL
                    suggestion_id in considered_suggestions && continue
                    push!(considered_suggestions, suggestion_id)
                end

                # do not process higher distances than those already found, if verbosity<ALL (note:
                # max_edit_distance_2 will always equal max_edit_distance when Verbosity.ALL)
                if distance <= max_edit_distance_2
                    si = SuggestItem(suggestion, distance, suggestion_cnt)
                    if !isempty(suggestions)
                        if verbosity == VerbosityCLOSEST
                            # we will calculate DamLev distance
                            # only to the smallest found distance so far
                            if distance < max_edit_distance_2
                                empty!(suggestions)
                            end
                        elseif verbosity == VerbosityTOP
                            suggestions[1] = si < suggestions[1] ? si : suggestions[1]
                            max_edit_distance_2 = distance
                            continue
                        end
                    end

                    if verbosity != VerbosityALL
                        max_edit_distance_2 = distance
                    end
                    push!(suggestions, si)
                end
            end
        end

        # add edits: derive edits (deletes) from candidate (phrase)
        # and add them to candidates list. this is a recursive
        # process until the maximum edit distance has been reached
        if len_diff < max_edit_distance && candidate_len <= dict.prefix_length
            # do not create edits with edit distance smaller than
            # suggestions already found
            if verbosity != VerbosityALL && len_diff >= max_edit_distance_2
                continue
            end
            add_edits!(considered_deletes, candidates, candidate, candidate_len)
        end
    end

    if length(suggestions) > 1
        sort!(suggestions)
    end

    if transfer_casing
        for (i, s) in enumerate(suggestions)
            suggestions[i] = SuggestItem(transfer_casing_for_similar_text(phrase_original, s.term), s.distance, s.count)
        end
    end

    early_exit()

    return suggestions
end

@inline function simple_filter(phrase_len::Int, phrase_prefix_len::Int, suggestion_len::Int,
     candidate_len::Int, max_edit_distance_2::Int, prefix_length::Int)

    phrase_len - suggestion_len > max_edit_distance_2 && return false
    suggestion_len - phrase_len > max_edit_distance_2 && return false
    suggestion_len < candidate_len && return false

    suggestion_prefix_len = suggestion_len > prefix_length ? prefix_length : suggestion_len

    ((suggestion_prefix_len > phrase_prefix_len) &
        (suggestion_prefix_len - candidate_len > max_edit_distance_2)) &&
        return false

    if candidate_len == 0
        # suggestions which have no common chars with phrase (phrase_len<=max_edit_distance &&
        # suggestion_len<=max_edit_distance)

        distance = max(phrase_len, suggestion_len)
        distance > max_edit_distance_2 && return false
    end

    return true
end

@inline function equal_suffixes(phrase::String32, suggestion::String32, min_distance)
    id1 = length(phrase) + 2 - min_distance
    id2 = length(suggestion) + 2 - min_distance
    for i in 0:(length(phrase) - id1)
        @inbounds phrase[id1 + i] != suggestion[id2 + i] && return true
    end

    return false
end

@inline function add_edits!(considered_deletes, candidates, candidate, candidate_len)
    sz = ncodeunits(candidate)
    idx1 = 0
    idx2 = nextind(candidate, idx1)
    idx3 = idx2
    for i in eachindex(0:candidate_len-1)
        idx3 = nextind(candidate, idx3)
        # black magic, fast string with deleted character
        delete = Base._string_n(sz - idx3 + idx2)
        unsafe_copyto!(pointer(delete), pointer(candidate), idx2 - 1)
        unsafe_copyto!(pointer(delete, idx2), pointer(candidate, idx3), sz - idx3 + 1)
        idx1 = idx2
        idx2 = idx3
        if !(delete in considered_deletes)
            push!(considered_deletes, delete)
            push!(candidates, delete)
        end
    end
end
