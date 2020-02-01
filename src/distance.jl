########################################################################################
#
# Creates the DamerauLevenshtein metric
# The DamerauLevenshtein distance is the minimum number of operations (consisting of insertions,
# deletions or substitutions of a single character, or transposition of two adjacent characters)
# required to change one string into the other.
#
# Initial implementation based on http://blog.softwx.net/2015/01/optimizing-damerau-levenshtein_15.html
#
# This implementation based on https://github.com/matthieugomez/StringDistances.jl
#


function common_prefix(s1::String32, s2::String32)
    l = 1
    ls1 = length(s1)
    ls2 = length(s2)
    while l <= ls1 && l <= ls2
        s1[l] != s2[l] && break
        l += 1
    end
    return l - 1
end

function evaluate!(t1::String32, t2::String32, max_dist::Int, v0::Vector{Int}, v2::Vector{Int})
    if length(t1) > length(t2)
        t1, t2 = t2, t1
    end
    len1, len2 = length(t1), length(t2)
    len2 - len1 > max_dist && return max_dist + 1
    # prefix common to both strings can be ignored
    k = common_prefix(t1, t2)
    k == len1 && return len2 - k
    for i in 1:(len2 - k)
        v0[i] = i
    end

    offset = 1 + max_dist - (len2 - len1)
    i2_start = 1
    i2_end = max_dist

    i1 = 1
    current = i1
    prevch1 = t1[k + 1]
    for i in k+1:len1
        ch1 = t1[i]
        left = (i1 - 1)
        current = i1
        nextTransCost = 0
        prevch2 = t2[k + 1]
        i2_start += (i1 > offset) ? 1 : 0
        i2_end = min(i2_end + 1, len2)
        i2 = 1
        for j in k+1:len2
            @inbounds ch2 = t2[j]
            if i2_start <= i2 <= i2_end
                above = current
                thisTransCost = nextTransCost
                @inbounds nextTransCost = v2[i2]
                # cost of diagonal (substitution)
                @inbounds v2[i2] = current = left
                # left now equals current cost (which will be diagonal at next iteration)
                @inbounds left = v0[i2]
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
            i2 += 1
            prevch2 = ch2
        end
        @inbounds v0[i1 + len2 - len1] > max_dist && return max_dist + 1
        i1 += 1
        prevch1 = ch1
    end

    return current
end
