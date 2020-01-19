@enum Verbosity VerbosityTOP VerbosityCLOSEST VerbosityALL

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
        max_edit_distance = dict.max_dictionary_edit_distance)
    if max_edit_distance > dict.max_dictionary_edit_distance
        throw(ArgumentError("Distance $max_edit_distance larger than dictionary threshold $(dict.max_edit_distance)"))
    end

    suggestions = []
    phrase_len = length(phrase)

    if transfer_casing
        phrase = lowercase(phrase)
    end

    function early_exit()
        if include_unknown && isempty(suggestions)
            push!(suggestions, SuggestItem(phrase, max_edit_distance + 1, 0))
        end
        suggestions
    end

    # early exit - word is too big to possibly match any words
    if phrase_len - max_edit_distance > dict.max_length
        return early_exit()
    end

    # quick look for exact match
    suggestion_cnt = 0
    if phrase in keys(dict.words)
        suggestion_cnt = dict.words[phrase]
        push!(suggestions, SuggestItem(phrase, 0, suggestion_cnt))

        # early exit - return exact match, unless caller wants all
        # matches
        if verbosity != VerbosityALL
            return early_exit()
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

    considered_deletes = Set()
    considered_suggestions = Set()

    # we considered the phrase already in the
    # 'phrase in self._words' above
    push!(considered_suggestions, phrase)

    max_edit_distance_2 = max_edit_distance
    candidates = []

    # add original prefix
    phrase_prefix_len = phrase_len
    if phrase_prefix_len > dict.prefix_length
        phrase_prefix_len = dict.prefix_length
        push!(candidates, phrase[1:phrase_prefix_len])
    else
        push!(candidates, phrase)
    end

    distance_comparer = EditDistance(dict.distance_algorithm)
    for candidate in candidates
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
            dict_suggestions = dict.deletes[candidate]
            for suggestion in dict_suggestions
                suggestion == phrase && continue
                suggestion_len = length(suggestion)

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
                    (distance > max_edit_distance_2 || suggestion in considered_suggestions)
                    continue
                elseif suggestion_len == 1
                    # TODO: correct!!!
                    # distance = ??? phrase[suggestion[0]] < 0 ? phrase_len : phrase_len - 1
                    (distance > max_edit_distance_2 || suggestion in considered_suggestions)
                    continue

                # number of edits in prefix == maxediddistance AND
                # no identical suffix, then
                # editdistance>max_edit_distance and no need for
                # Levenshtein calculation
                # (phraseLen >= prefixLength) &&
                # (suggestionLen >= prefixLength)
                else
                    # handles the shortcircuit of min_distance
                    # assignment when first boolean expression
                    # evaluates to false

                    if dict.prefix_length - max_edit_distance == candidate_len
                        min_distance = min(phrase_len, suggestion_len) = dict.prefix_length
                    else
                        min_distance = 0
                    end

                    if (dict.prefix_length - max_edit_distance == candidate_len) &&
                        (min_distance > 1 && phrase[phrase_len + 1 - min_distance:end] != suggestion[suggestion_len + 1 - min_distance:end]) ||
                        (min_distance > 0 &&
                            phrase[phrase_len - min_distance] != suggestion[suggestion_len - min_distance] &&
                            (phrase[phrase_len - min_distance - 1] != suggestion[suggestion_len - min_distance] ||
                                phrase[phrase_len - min_distance] != suggestion[suggestion_len - min_distance - 1]
                            ))
                        continue
                    else
                        # delete_in_suggestion_prefix is somewhat
                        # expensive, and only pays off when
                        # verbosity is TOP or CLOSEST
                        if (verbosity != VerbosityALL &&
                            !delete_in_suggestion_prefix(candidate, suggestion, dict.prefix_length, candidate_len, suggestion_len)) ||
                            suggestion in considered_suggestions
                            continue
                        end
                        push!(considered_suggestions, suggestion)
                        distance = distance_comparer.compare(phrase, suggestion, max_edit_distance_2)
                        distance < 0 && continue
                    end

                    # do not process higher distances than those
                    # already found, if verbosity<ALL (note:
                    # max_edit_distance_2 will always equal
                    # max_edit_distance when Verbosity.ALL)
                    if distance <= max_edit_distance_2
                        suggestion_cnt = dict.words[suggestion]
                        si = SuggestItem(suggestion, distance, suggestion_cnt)
                        if !isempty(suggestions)
                            if verbosity == VerbosityCLOSEST
                                # we will calculate DamLev distance
                                # only to the smallest found distance
                                # so far
                                if distance < max_edit_distance_2
                                    suggestions = []
                                end
                            elseif verbosity == VerbosityTOP
                                if distance < max_edit_distance_2 ||
                                    suggestion_cnt > suggestions[1].count
                                    suggestions[1] = si
                                end
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
                for i in 1:candidate_len
                    delete = candidate[1:i - 1] + candidate[i+1:end]
                    if !(delete in considered_deletes)
                        push!(considered_deletes, delete)
                        push!(candidates, delete)
                    end
                end
            end

        end
        if length(suggestions) > 1
            sort!(suggestions)
        end

        if transfer_casing
            suggestions = [SuggestItem(transfer_casing_for_similar_text(original_phrase, s.term), s.distance, s.count)
                for s in suggestions]
        end
    end
    early_exit()

    return suggestions
end

"""
    delete_in_suggestion_prefix(dict, delete, delete_len, suggestion, suggestion_len)

Check whether all delete chars are present in the suggestion
prefix in correct order, otherwise this is just a hash
collision
"""
function delete_in_suggestion_prefix(delete, suggestion, prefix_len, delete_len, suggestion_len)
    delete_len == 0 && return true
    suggestion_len = prefix_len < suggestion_len ? prefix_len : suggestion_len

    j = 0
    for i in 1:delete_len
        del_char = delete[i]
        while j < suggestion_len && del_char != suggestion[j]
            j += 1
        end

        j == suggestion_len && return false
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
    caseof(s) = isuppercase(s) ? uppercase : lowercase
    for (tag, i1, i2, j1, j2) in get_opcodes(lowercase(text_w_casing), text_wo_casing)
        if tag == "insert"
            # if this is the first character and so there is no
            # character on the left of this or the left of it a space
            # then take the casing from the following character
            # otherwise just take the casing from the prior
            # character
            idx = i1 == 1 || text_w_casing[i1 - 1] == ' ' ? i1 : i1 - 1
            res *= caseof(text_w_casing[idx])(text_wo_casing[j1:j2])
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
                last_case = lowercase
                for (w, wo) in zip(w_casing, wo_casing)
                    last_case = caseof(w)
                    res *= last_case(wo)
                end
                # once we ran out of 'w', we will carry over
                # the last casing to any additional 'wo'
                # characters
                res *= last_case(wo_casing[length(w_casing) + 1:end])
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
