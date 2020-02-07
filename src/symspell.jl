import Base: ==

# Rudimentary fixed width string. Nothing fancy just bare minimum, for
# lookup fast string manipulations. Unfortunately `nextind` and other string functions
# are notoriously slow.
struct String32 <: AbstractString
    s::Vector{Char}
    l::Int
end

function String32(s::S) where {S <: AbstractString}
    x = Vector{Char}(s)
    return String32(x, length(x))
end

String32(s::String32) = s

Base.:length(s::String32) = s.l
==(s1::String32, s2::String32) = (s1.s == s2.s) & (s1.l == s2.l)

function Base.:iterate(s::String32, state::Integer = 1)
    state > length(s.s) && return nothing
    return (s.s[state], state + 1)
end

Base.:ncodeunits(s::String32) = s.l
Base.:isvalid(s::String32, i::Integer) = true
Base.:lowercase(x::String32) = String32(lowercase.(x.s), x.l)
Base.:getindex(x::String32, i::Integer) = x.s[i]

struct DictWord{T <: Integer}
    word::String32
    count::T
end

DictWord(word::String, count::T) where {T <: Integer} = DictWord{T}(String32(word), count)

==(dw1::DictWord{T}, dw2::DictWord{T}) where {T <: Integer} = (dw1.word == dw2.word) & (dw1.count == dw2.count)
Base.:length(dw::DictWord) = length(dw.word)

mutable struct LookupOptions
    include_unknown::Bool
    ignore_token::Union{Nothing,AbstractString,Regex,AbstractChar}
    transfer_casing::Bool
    verbosity::Verbosity
    max_edit_distance::Int
end

mutable struct SymSpell{T <: Integer, K <: Unsigned}
    words::Vector{DictWord{T}}
    below_threshold_words::Dict{String, T}
    deletes::Dict{String, Vector{K}}
    words_idx::Dict{String, K}

    max_dictionary_edit_distance::Int
    prefix_length::Int
    count_threshold::Int
    max_length::Int

    lookup::LookupOptions
end

SymSpell(; max_dictionary_edit_distance = 2, prefix_length = 7, count_threshold = 1) =
    SymSpell{Int, UInt32}(Vector(), Dict(), Dict(), Dict(),
        max_dictionary_edit_distance, prefix_length, count_threshold, 0,
        LookupOptions(false, nothing, false, VerbosityTOP, max_dictionary_edit_distance))


function SymSpell(path; sep = " ", max_dictionary_edit_distance = 2, prefix_length = 7, count_threshold = 1)
    d = SymSpell(max_dictionary_edit_distance = max_dictionary_edit_distance,
                    prefix_length = prefix_length, count_threshold = count_threshold)
    update!(d, path, sep = sep)
end

# TODO: add support for DataFrames and CSV
function update!(dict::SymSpell{T, K}, path; sep = " ") where {T, K}
    for line in eachline(path)
        line_parts = strip.(split(line, sep))
        if length(line_parts) >= 2
            push!(dict, string(line_parts[1]), parse(T, strip(line_parts[2])))
        end
    end

    # this sorting increases chance of early stop on TOP/CLOSEST verbosity level
    for v in values(dict.deletes)
        sort!(v, by = idx -> length(dict.words[idx]))
    end

    dict
end


"""
    edits!(delete_words, word, edit_distance, max_dictionary_distance)

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

function edits_prefix(key::S, max_dictionary_edit_distance, prefix_length) where {S <: AbstractString}
    hash_set = Set{S}()

    if length(key) <= max_dictionary_edit_distance
        push!(hash_set, "")
    end
    if length(key) > prefix_length
        key = key[1:nextind(key, 0, prefix_length)]
    end
    push!(hash_set, key)
    edits!(hash_set, key, 0, max_dictionary_edit_distance)
end

function Base.:push!(dict::SymSpell{T, K}, key, cnt) where {T, K}
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
    elseif key in keys(dict.words_idx)
        # just update count if it's an already added above
        # threshold word
        idx = dict.words_idx[key]
        cnt_prev = dict.words[idx].count
        dict.words[idx] = DictWord(dict.words[idx].word, typemax(T) - cnt_prev > cnt ? cnt_prev + cnt : typemax(T))
        return false
    elseif cnt < dict.count_threshold
        # new below threshold word
        dict.below_threshold_words[key] = cnt
        return false
    end

    # what we have at this point is a new, above threshold word
    push!(dict.words, DictWord(key, cnt))
    idx = K(length(dict.words))
    dict.words_idx[key] = idx

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
        push!(get!(dict.deletes, delete, []), idx)
    end

    return true
end
