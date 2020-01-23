mutable struct SymSpell{S <: AbstractString, T <: Integer}
    words::Dict{S, T}
    below_threshold_words::Dict{S, T}
    deletes::Dict{S, Vector{S}}

    max_dictionary_edit_distance::Int
    prefix_length::Int
    count_threshold::Int
    max_length::Int
end

SymSpell(; max_dictionary_edit_distance = 2, prefix_length = 7, count_threshold = 1) =
    SymSpell{String, Int}(Dict(), Dict(), Dict(),
        max_dictionary_edit_distance, prefix_length, count_threshold, 0)

function SymSpell(path; sep = " ", max_dictionary_edit_distance = 2, prefix_length = 7, count_threshold = 1)
    d = SymSpell(max_dictionary_edit_distance = max_dictionary_edit_distance,
                    prefix_length = prefix_length, count_threshold = count_threshold)
    update!(d, path, sep = sep)
end

# TODO: add support for DataFrames and CSV
function update!(dict::SymSpell{S, T}, path; sep = " ") where {S, T}
    for line in eachline(path)
        line_parts = strip.(split(line, sep))
        if length(line_parts) >= 2
            push!(dict, line_parts[1], parse(T, line_parts[2]))
        end
    end
    dict
end


"""
    edits(dict, word, edit_distance, delete_words)

Inexpensive and language independent: only deletes, no transposes + replaces + inserts
replaces and inserts are expensive and language dependent
"""
function edits!(delete_words, word, edit_distance, max_dictionary_edit_distance)
    edit_distance += 1
    word_len = length(word)
    if word_len > 1
        let i = 0
            while i < lastindex(word)
                delete = word[1:i] * word[nextind(word, nextind(word, i)):end]
                i = nextind(word, i)
                if !(delete in delete_words)
                    push!(delete_words, delete)
                    # recursion, if maximum edit distance not yet reached
                    if edit_distance < max_dictionary_edit_distance
                        edits!(delete_words, delete, edit_distance, max_dictionary_edit_distance)
                    end
                end
            end
        end
    end

    return delete_words
end

@inline function conv_idx(word, i)
    k = 0
    for j in 1:i
        k = nextind(word, k)
    end
    k
end

function edits_prefix(key::S, max_dictionary_edit_distance, prefix_length) where S
    hash_set = Set{S}()

    if length(key) <= max_dictionary_edit_distance
        push!(hash_set, "")
    end
    if length(key) > prefix_length
        key = key[1:conv_idx(key, prefix_length)]
    end
    push!(hash_set, key)
    edits!(hash_set, key, 0, max_dictionary_edit_distance)
end

function Base.:push!(dict::SymSpell{S, T}, key, cnt) where {T <: Integer, S <: AbstractString}
    if cnt < 0
        if dict.count_threshold > 0 return false end
        cnt = 0
    end

    # look first in below threshold words, update count, and allow
    # promotion to correct spelling word if count reaches threshold
    # threshold must be >1 for there to be the possibility of low
    # threshold words
    if dict.count_threshold > 1 && key in keys(dict.below_threshold_words)
        cnt_prev = dict.below_threshold_words[key]
        # calculate new count for below threshold word
        cnt = typemax(T) - cnt_prev > cnt ? cnt_prev + cnt : typemax(T)
        # has reached threshold - remove from below threshold
        # collection (it will be added to correct words below)
        if cnt >= dict.count_threshold
            delete!(dict.below_threshold_words, key)
        else
            dict.below_threshold_words[key] = cnt
            return false
        end
    elseif key in keys(dict.words)
        # just update count if it's an already added above
        # threshold word
        cnt_prev = dict.words[key]
        dict.words[key] = typemax(T) - cnt_prev > cnt ? cnt_prev + cnt : typemax(T)
        return false
    elseif cnt < dict.count_threshold
        # new below threshold word
        dict.below_threshold_words[key] = cnt
        return false
    end

    # what we have at this point is a new, above threshold word
    dict.words[key] = cnt

    # edits/suggestions are created only once, no matter how often
    # word occurs. edits/suggestions are created as soon as the
    # word occurs in the corpus, even if the same term existed
    # before in the dictionary as an edit from another word
    if length(key) > dict.max_length
        dict.max_length = length(key)
    end

    # create deletes
    edits = edits_prefix(key, dict.max_dictionary_edit_distance, dict.prefix_length)
    for delete in edits
        push!(get!(dict.deletes, delete, S[]), key)
    end

    return true
end
