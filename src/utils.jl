@enum Verbosity VerbosityTOP VerbosityCLOSEST VerbosityALL

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

    return String(collect(isuppercase(x) ? uppercase(y) : lowercase(y) for (x, y) in zip(text_w_casing, text_wo_casing)))
end

# Based on the functionality of the python difflib get_opcodes()
function get_opcodes(s1::S1, s2::S2) where {S1 <: AbstractString, S2 <: AbstractString}
    res = Tuple{String, Int, Int, Int, Int}[]
    blocks = sort!(collect(matching_blocks(s1, s2)), by = x -> x[1])
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

    return res
end
