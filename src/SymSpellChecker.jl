module SymSpellChecker

using StringDistances: matching_blocks

export update!, SymSpell, lookup, term, set_options!

include("utils.jl")
include("symspell.jl")
include("distance.jl")
include("lookup.jl")

end # module
