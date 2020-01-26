struct StringWithLength{T <: AbstractString} <: AbstractString
    s::T
    l::Int
end
string_with_length(s::AbstractString) = StringWithLength(s, length(s))
Base.length(s::StringWithLength) = s.l
Base.iterate(s::StringWithLength, i::Integer = firstindex(s.s)) = iterate(s.s, i)
Base.nextind(s::StringWithLength, i::Int, n::Int = 1) = nextind(s.s, i, n)
Base.ncodeunits(s::StringWithLength) = ncodeunits(s.s)
Base.isvalid(s::StringWithLength, i::Int) = isvalid(s.s, i)

function reorder(s1::AbstractString, s2::AbstractString)
    s1 = string_with_length(s1)
    s2 = string_with_length(s2)
    if length(s1) <= length(s2)
         return s1, s2
    else
        return s2, s1
    end
end

function common_prefix(s1::AbstractString, s2::AbstractString)
    x1 = iterate(s1)
    x2 = iterate(s2)
    l = 0
    while (x1 !== nothing) & (x2 !== nothing)
        ch1, state1 = x1
        ch2, state2 = x2
        ch1 != ch2 && break
        l += 1
        x1 = iterate(s1, state1)
        x2 = iterate(s2, state2)
    end
    return l, x1, x2
end

# function evaluate3(s1::S1, s2::S2, max_dist) where {S1 <: AbstractString, S2 <: AbstractString}
#     t1 = collect(s1)
#     t2 = collect(s2)
#     if length(t1) > length(t2)
#         t1, t2 = t2, t1
#     end
#     len1, len2 = length(t1), length(t2)
#     len2 - len1 > max_dist && return max_dist + 1
#     # prefix common to both strings can be ignored
#     # k, x1, x2start = common_prefix(t1, t2)
#     k = common_prefix(t1, t2)
#     k == len1 && return len2 - k
#     v0 = collect(1:(len2 - k))
#     v2 = similar(v0)
#
#     offset = 1 + max_dist - (len2 - len1)
#     i2_start = 1
#     i2_end = max_dist
#
#     i1 = 1
#     current = i1
#     prevch1 = t1[k + 1]
#     for ch1 in t1[k + 1:end]
#         left = (i1 - 1)
#         current = i1
#         nextTransCost = 0
#         prevch2 = t2[k + 1]
#         i2_start += (i1 > offset) ? 1 : 0
#         i2_end = min(i2_end + 1, len2)
#         i2 = 1
#         for ch2 in t2[k + 1:end]
#             if i2_start <= i2 <= i2_end
#                 above = current
#                 thisTransCost = nextTransCost
#                 nextTransCost = v2[i2]
#                 # cost of diagonal (substitution)
#                 v2[i2] = current = left
#                 # left now equals current cost (which will be diagonal at next iteration)
#                 left = v0[i2]
#                 if ch1 != ch2
#                     # insertion
#                     if left < current
#                         current = left
#                     end
#                     # deletion
#                     if above < current
#                         current = above
#                     end
#                     current += 1
#                     if (i1 != 1) & (i2 != 1) & (ch1 == prevch2) & (prevch1 == ch2)
#                         thisTransCost += 1
#                         if thisTransCost < current
#                             current = thisTransCost
#                         end
#                     end
#                 end
#                 v0[i2] = current
#             end
#             i2 += 1
#             prevch2 = ch2
#         end
#         v0[i1 + len2 - len1] > max_dist && return max_dist + 1
#         i1 += 1
#         prevch1 = ch1
#     end
#
#     return current
# end

function evaluate2!(s1::S1, s2::S2, max_dist, v0, v2) where {S1 <: AbstractString, S2 <: AbstractString}
    s1, s2 = reorder(s1, s2)
    len1, len2 = length(s1), length(s2)
    len2 - len1 > max_dist && return max_dist + 1
    # prefix common to both strings can be ignored
    k, x1, x2start = common_prefix(s1, s2)
    (x1 == nothing) && return len2 - k
    for i in 1:(len2 - k)
        v0[i] = i
    end
    # v0 = collect(1:(len2 - k))
    # v2 = similar(v0)

    offset = 1 + max_dist - (len2 - len1)
    i2_start = 1
    i2_end = max_dist

    i1 = 1
    current = i1
    prevch1, = x1
    while x1 !== nothing
        ch1, state1 = x1
        left = (i1 - 1)
        current = i1
        nextTransCost = 0
        prevch2, = x2start
        i2_start += (i1 > offset) ? 1 : 0
        i2_end = min(i2_end + 1, len2)
        x2 = x2start
        i2 = 1
        while x2 !== nothing
            ch2, state2 = x2
            if i2_start <= i2 <= i2_end
                above = current
                thisTransCost = nextTransCost
                nextTransCost = v2[i2]
                # cost of diagonal (substitution)
                v2[i2] = current = left
                # left now equals current cost (which will be diagonal at next iteration)
                left = v0[i2]
                if ch1 != ch2
                    # insertion
                    if left < current
                        current = left
                    end
                    # deletion
                    if above < current
                        current = above
                    end
                    current += 1
                    if (i1 != 1) & (i2 != 1) & (ch1 == prevch2) & (prevch1 == ch2)
                        thisTransCost += 1
                        if thisTransCost < current
                            current = thisTransCost
                        end
                    end
                end
                v0[i2] = current
            end
            x2 = iterate(s2, state2)
            i2 += 1
            prevch2 = ch2
        end
        v0[i1 + len2 - len1] > max_dist && return max_dist + 1
        x1 = iterate(s1, state1)
        i1 += 1
        prevch1 = ch1
    end

    return current
end
#
# function common_prefix(s1, s2)
#     l = 1
#     ls1 = length(s1)
#     ls2 = length(s2)
#     while l <= ls1 && l <= ls2
#         s1[l] != s2[l] && break
#         l += 1
#     end
#     return l - 1
# end
#
# function evaluate3(t1, t2, max_dist)
#     # t1 = collect(s1)
#     # t2 = collect(s2)
#     if length(t1) > length(t2)
#         t1, t2 = t2, t1
#     end
#     len1, len2 = length(t1), length(t2)
#     len2 - len1 > max_dist && return max_dist + 1
#     # prefix common to both strings can be ignored
#     # k, x1, x2start = common_prefix(t1, t2)
#     k = common_prefix(t1, t2)
#     k == len1 && return len2 - k
#     v0 = collect(1:(len2 - k))
#     v2 = similar(v0)
#
#     offset = 1 + max_dist - (len2 - len1)
#     i2_start = 1
#     i2_end = max_dist
#
#     i1 = 1
#     current = i1
#     prevch1 = t1[k + 1]
#     for i in k+1:len1
#         ch1 = t1[i]
#         left = (i1 - 1)
#         current = i1
#         nextTransCost = 0
#         prevch2 = t2[k + 1]
#         i2_start += (i1 > offset) ? 1 : 0
#         i2_end = min(i2_end + 1, len2)
#         i2 = 1
#         for j in k+1:len2
#             ch2 = t2[j]
#             if i2_start <= i2 <= i2_end
#                 above = current
#                 thisTransCost = nextTransCost
#                 nextTransCost = v2[i2]
#                 # cost of diagonal (substitution)
#                 v2[i2] = current = left
#                 # left now equals current cost (which will be diagonal at next iteration)
#                 left = v0[i2]
#                 if ch1 != ch2
#                     # insertion
#                     if left < current
#                         current = left
#                     end
#                     # deletion
#                     if above < current
#                         current = above
#                     end
#                     current += 1
#                     if (i1 != 1) & (i2 != 1) & (ch1 == prevch2) & (prevch1 == ch2)
#                         thisTransCost += 1
#                         if thisTransCost < current
#                             current = thisTransCost
#                         end
#                     end
#                 end
#                 v0[i2] = current
#             end
#             i2 += 1
#             prevch2 = ch2
#         end
#         v0[i1 + len2 - len1] > max_dist && return max_dist + 1
#         i1 += 1
#         prevch1 = ch1
#     end
#
#     return current
# end
