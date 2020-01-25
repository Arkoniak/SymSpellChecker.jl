@enum Verbosity VerbosityTOP VerbosityCLOSEST VerbosityALL

struct SuggestItem{T <: AbstractString}
    term::T
    distance::Int
    count::Int
end

Base.:isless(si1::SuggestItem, si2::SuggestItem) = (si1.distance < si2.distance) ||
    ((si1.distance == si2.distance) && (si1.count > si2.count)) ||
    ((si1.distance == si2.distance) && (si1.count == si2.count) && (si1.term < si2.term))

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
function lookup(dict, phrase; include_unknown = false, ignore_token = nothing,
        transfer_casing = false, verbosity = VerbosityTOP,
        max_edit_distance = dict.max_dictionary_edit_distance,
        compare_algorithm = DamerauLevenshtein())

        lookup(dict, phrase, include_unknown, ignore_token, transfer_casing, verbosity, max_edit_distance, compare_algorithm)
end

Base.:getindex(dict, phrase) = lookup(dict, phrase)

function lookup(dict::SymSpell{S2, T, K}, phrase::S, include_unknown, ignore_token,
                transfer_casing, verbosity,
                max_edit_distance,
                compare_algorithm) where {S, S2, T, K}
    if max_edit_distance > dict.max_dictionary_edit_distance
        throw(ArgumentError("Distance $max_edit_distance larger than dictionary threshold $(dict.max_dictionary_edit_distance)"))
    end

    suggestions = SuggestItem{S}[]
    phrase_len = length(phrase)

    if transfer_casing
        phrase = lowercase(phrase)
    end

    early_exit = let phrase = phrase, suggestions = suggestions, include_unknown = include_unknown, max_edit_distance = max_edit_distance
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
    suggestion_cnt = 0
    idx = K(0)
    if phrase in keys(dict.deletes)
        idx = first(dict.deletes[phrase])
        may_be_suggestion, suggestion_cnt = dict.words[idx]
        # if may_be_suggestion != phrase, than it's false alarm
        if may_be_suggestion == phrase
            push!(suggestions, SuggestItem(phrase, 0, suggestion_cnt))
            # early exit - return exact match, unless caller wants all
            # matches
            if verbosity != VerbosityALL
                return suggestions
            end
        else
            idx = K(0)
        end
    end

    if ignore_token != nothing && occursin(ignore_token, phrase)
        suggestion_cnt = 1
        push!(suggestions, SuggestItem(phrase, 0, suggestion_cnt))
        # early exit - return exact match, unless caller wants all
        # matches
        if verbosity != VerbosityALL
            return early_exit()
        end
    end

    # early termination, if we only want to check if word in
    # dictionary or get its frequency e.g. for word segmentation
    if max_edit_distance == 0
        return early_exit()
    end

    considered_deletes = Set{S}()
    considered_suggestions = Set{K}()

    # we considered the phrase already in the
    # 'phrase in keys(dict.words)' above
    if idx > 0
        push!(considered_suggestions, idx)
    end

    max_edit_distance_2 = max_edit_distance
    candidates = S[]

    # add original prefix
    phrase_prefix_len = min(phrase_len, dict.prefix_length)
    push!(candidates, phrase[1:nextind(phrase, 0, phrase_prefix_len)])

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
                @inbounds suggestion, suggestion_cnt, suggestion_len = dict.words[suggestion_id]

                # phrase and suggestion lengths
                # diff > allowed/current best distance
                if abs(suggestion_len - phrase_len) > max_edit_distance_2 ||
                    # suggestion must be for a different delete
                    # string, in same bin only because of hash
                    # collision
                    (suggestion_len < candidate_len) ||
                    # if suggestion len = delete len, then it
                    # either equals delete or is in same bin
                    # only because of hash collision
                    (suggestion_len == candidate_len && suggestion != candidate)
                    continue
                end
                suggestion_prefix_len = min(suggestion_len, dict.prefix_length)
                if (suggestion_prefix_len > phrase_prefix_len) &&
                    (suggestion_prefix_len - candidate_len > max_edit_distance_2)
                    continue
                end

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
                distance = 0
                min_distance = 0
                if candidate_len == 0
                    # suggestions which have no common chars with
                    # phrase (phrase_len<=max_edit_distance &&
                    # suggestion_len<=max_edit_distance)

                    distance = max(phrase_len, suggestion_len)
                    distance > max_edit_distance_2 && continue
                elseif suggestion_len == 1
                    # TODO: correct!!!
                    # distance = ??? phrase[suggestion[0]] < 0 ? phrase_len : phrase_len - 1
                    distance > max_edit_distance_2 && continue
                end

                suggestion_id in considered_suggestions && continue
                # number of edits in prefix == maxediddistance AND
                # no identical suffix, then
                # editdistance>max_edit_distance and no need for
                # Levenshtein calculation
                # (phraseLen >= prefixLength) &&
                # (suggestionLen >= prefixLength)

                # handles the shortcircuit of min_distance
                # assignment when first boolean expression
                # evaluates to false
                if dict.prefix_length - max_edit_distance == candidate_len
                    min_distance = min(phrase_len, suggestion_len) - dict.prefix_length

                    min_distance > 1 &&
                        equal_suffixes(phrase, phrase_len, suggestion, suggestion_len, min_distance) && continue
                    if min_distance > 0
                        p1 = nextind(phrase, 0, phrase_len + 1 - min_distance)
                        s1 = nextind(suggestion, 0, suggestion_len + 1 - min_distance)
                        @inbounds if phrase[p1] != suggestion[s1]
                            p2 = prevind(phrase, p1)
                            s2 = prevind(suggestion, s1)
                            @inbounds (phrase[p2] != suggestion[s1] || phrase[p1] != suggestion[s2]) && continue
                        end
                    end
                end

                # delete_in_suggestion_prefix is somewhat
                # expensive, and only pays off when
                # verbosity is TOP or CLOSEST
                if verbosity != VerbosityALL &&
                    !delete_in_suggestion_prefix(candidate, suggestion, dict.prefix_length)
                    continue
                end
                push!(considered_suggestions, suggestion_id)
                distance = evaluate(compare_algorithm, phrase, suggestion, max_dist = max_edit_distance_2)

                # do not process higher distances than those
                # already found, if verbosity<ALL (note:
                # max_edit_distance_2 will always equal
                # max_edit_distance when Verbosity.ALL)
                if distance <= max_edit_distance_2
                    si = SuggestItem(suggestion, distance, suggestion_cnt)
                    if !isempty(suggestions)
                        if verbosity == VerbosityCLOSEST
                            # we will calculate DamLev distance
                            # only to the smallest found distance
                            # so far
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
        suggestions = [SuggestItem(transfer_casing_for_similar_text(original_phrase, s.phrase), s.distance, s.count)
                        for s in suggestions]
    end

    early_exit()

    return suggestions
end

@inline function equal_suffixes(phrase, phrase_len, suggestion, suggestion_len, min_distance)
    id1 = nextind(phrase, 0, phrase_len + 2 - min_distance)
    id2 = nextind(suggestion, 0, suggestion_len + 2 - min_distance)
    sz = ncodeunits(phrase)
    @inbounds for i in 1:(sz - id1 + 1)
        codeunit(phrase, id1) != codeunit(suggestion, id2) && return true
        id1 += 1
        id2 += 1
    end

    return false
end

function add_edits!(considered_deletes, candidates, candidate, candidate_len)
    idx1 = 0
    idx2 = nextind(candidate, idx1)
    idx3 = idx2
    for i in eachindex(0:candidate_len-1)
        idx3 = nextind(candidate, idx3)
        delete = candidate[1:idx1] * candidate[idx3:end]
        idx1 = idx2
        idx2 = idx3
        if !(delete in considered_deletes)
            push!(considered_deletes, delete)
            push!(candidates, delete)
        end
    end
end

"""
    delete_in_suggestion_prefix(dict, delete, delete_len, suggestion, suggestion_len)

Check whether all delete chars are present in the suggestion
prefix in correct order, otherwise this is just a hash
collision
"""
function delete_in_suggestion_prefix(delete, suggestion, prefix_len)
    isempty(delete) && return true
    suggestion_len = min(prefix_len, length(suggestion))

    # TODO: verify that by construction delete_len always <= prefix_len and this line can be removed
    delete_len = min(prefix_len, length(delete))

    j = 1
    j_cnt = 0
    i = 1
    for _ in 1:delete_len
        while j_cnt <= suggestion_len && delete[i] != suggestion[j]
            j = nextind(suggestion, j)
            j_cnt += 1
        end
        j_cnt > suggestion_len && return false
        i = nextind(delete, i)
    end

    return true
end

######
# Helpers

"""
    transfer_casing_for_similar_text(text_w_casing, text_wo_casing)
"""
function transfer_casing_for_similar_text(text_w_casing, text_wo_casing)
    isempty(text_wo_casing) && return text_wo_casing
    isempty(text_w_casing) && throw(ArgumentError("Empty 'text_w_casing', we need to know what casing to transfer"))

    # we will collect the case_text:
    res = ""

    # get the operation codes describing the differences between the
    # two strings and handle them based on the per operation code rules
    transfer(c1, c2) = isuppercase(c1) ? uppercase(c2) : lowercase(c2)
    for (tag, i1, i2, j1, j2) in get_opcodes(lowercase(text_w_casing), text_wo_casing)
        if tag == "insert"
            # if this is the first character and so there is no
            # character on the left of this or the left of it a space
            # then take the casing from the following character
            # otherwise just take the casing from the prior
            # character
            idx = i1 == 1 || text_w_casing[i1 - 1] == ' ' ? i1 : i1 - 1
            res *= transfer(text_w_casing[idx], text_wo_casing[j1:j2])
        elseif tag == "delete"
            # for deleted characters we don't need to do anything
        elseif tag == "equal"
            # for 'equal' we just transfer the text from the
            # text_w_casing, as anyhow they are equal (without the
            # casing)
            res *= text_w_casing[i1:i2]
        elseif tag == "replace"
            w_casing = text_w_casing[i1:i2]
            wo_casing = text_wo_casing[j1:j2]

            # if they are the same length, the transfer is easy
            if length(w_casing) == length(wo_casing)
                res *= transfer_casing_for_matching_text(w_casing, wo_casing)
            else
                # if the replaced has a different length, then we
                # transfer the casing character-by-character and using
                # the last casing to continue if we run out of the
                # sequence
                last_case = 'a'
                for (w, wo) in zip(w_casing, wo_casing)
                    last_case = w
                    res *= transfer(w, wo)
                end
                # once we ran out of 'w', we will carry over
                # the last casing to any additional 'wo'
                # characters
                res *= transfer(last_case, wo_casing[length(w_casing) + 1:end])
            end
        end
    end

    return res
end

"""
    transfer_casing_for_matching_text(text_w_casing, text_wo_casing)

Transferring the casing from one text to another - assuming that
they are 'matching' texts, alias they have the same length.
Parameters
----------
text_w_casing : str
    Text with varied casing
text_wo_casing : str
    Text that is in lowercase only
Returns
-------
str
    Text with the content of `text_wo_casing` and the casing of
    `text_w_casing`
Raises
------
ArgumentError
    If the input texts have different lengths
"""
function transfer_casing_for_matching_text(text_w_casing, text_wo_casing)
    if length(text_w_casing) != length(text_w_casing)
        throw(ArgumentError("The 'text_w_casing' and 'text_wo_casing' don't have the same length,
        so you can't use them with this method, you should be using the more general
        transfer_casing_similar_text() method."))
    end

    return join(isuppercase(x) ? uppercase(y) : lowercase(y) for (x, y) in zip(text_w_casing, text_wo_casing))
end


###########################################
# Based on python difflib get_opcodes()

using StringDistances

function get_opcodes(s1::AbstractString, s2::AbstractString)
    res = Tuple{String, Int, Int, Int, Int}[]
    blocks = sort!(collect(StringDistances.matching_blocks(s1, s2)), by = x -> x[1])
    i1, i2 = 1, 1
    for block in blocks
        if i1 < block[1] && i2 == block[2]
            push!(res, ("delete", i1, block[1] - 1, i2, block[2] - 1))
        elseif i1 == block[1] && i2 < block[2]
            push!(res, ("insert", i1, block[1] - 1, i2, block[2] - 1))
        elseif i1 < block[1] && i2 < block[2]
            push!(res, ("replace", i1, block[1] - 1, i2, block[2] - 1))
        end
        i1 = block[1] + block[3]
        i2 = block[2] + block[3]
        push!(res, ("equal", block[1], i1 - 1, block[2], i2 - 1))
    end
    if i1 <= length(s1) && i2 > length(s2)
        push!(res, ("delete", i1, length(s1), i2, i2 - 1))
    elseif i1 > length(s1) && i2 <= length(s2)
        push!(res, ("insert", i1, i1 - 1, i2, length(s2)))
    elseif i1 <= length(s1) && i2 <= length(s2)
        push!(res, ("replace", i1, length(s1), i2, length(s2)))
    end

    res
end
