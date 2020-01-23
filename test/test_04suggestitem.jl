module TestSuggestItem

include("preamble.jl")

using SymSpellChecker: SuggestItem

@testset "relations" begin
    si1 = SuggestItem("foo", 1, 5)
    si2 = SuggestItem("bar", 2, 20)
    @test si1 < si2

    si3 = SuggestItem("bzr", 2, 15)
    @test si2 < si3

    si4 = SuggestItem("bbr", 2, 20)
    @test si2 < si4
end

end
