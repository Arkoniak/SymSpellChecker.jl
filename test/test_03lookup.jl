module TestLookup

include("preamble.jl")

using SymSpell: SuggestItem, delete_in_suggestion_prefix

@testset "utility functions" begin
    @test delete_in_suggestion_prefix("bc", "bc", 7)
    @test delete_in_suggestion_prefix("xyz", "axbyczkkkkkkkkkk", 7)
    @test delete_in_suggestion_prefix("xyzmmmmm", "xyzkkkkkkkkkk", 3)
    @test !delete_in_suggestion_prefix("xyz", "axbykkkkkkkkkk", 7)
end

@testset "basic lookup" begin
    d = Dictionary()

    push!(d, "a", 5)
    push!(d, "bc", 2)

    @test_throws ArgumentError lookup(d, "xyz", max_edit_distance = 3)

    @test isempty(lookup(d, "qwerty"))
    @test lookup(d, "qwerty", include_unknown = true) == [SuggestItem("qwerty", 3, 0)]
    @test lookup(d, "bc") == [SuggestItem("bc", 0, 2)]
    @test lookup(d, "qwe", max_edit_distance = 0, include_unknown = true) == [SuggestItem("qwe", 1, 0)]
    @test lookup(d, "abc", max_edit_distance = 1) == [SuggestItem("bc", 1, 2)]
end


end # module
