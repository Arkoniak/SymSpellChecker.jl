module TestSymSpell
include("preamble.jl")

@testset "dictionary creation" begin
    d = SymSpell()

    @test push!(d, "a", 2)
    @test d.words == [("a", 2)]
    @test isempty(d.below_threshold_words)
    @test d.deletes == Dict{String, Vector{UInt32}}("" => [1], "a" => [1])

    push!(d, "bc", 2)
    @test d.max_length == 2

    d = SymSpell(count_threshold = 2)
    push!(d, "a", 100)
    push!(d, "bc", 100)
    push!(d, "c", 1)
    @test length(d.words) == 2
    @test length(d.below_threshold_words) == 1

    push!(d, "c", 1)
    @test length(d.words) == 3
    @test length(d.below_threshold_words) == 0

    d = SymSpell(max_dictionary_edit_distance = 1)
    push!(d, "abc", 100)
    @test d.deletes == Dict{String, Vector{UInt32}}("bc" => [1], "ac" => [1], "ab" => [1], "abc" => [1])

    push!(d, "abd", 100)
    @test d.deletes["ab"] == UInt32[1, 2]

    d = SymSpell(max_dictionary_edit_distance = 1)
    push!(d, "world", 10)
    push!(d, "word", 5)
    @test d.words[first(d.deletes["word"])] == ("word", 5)
end

@testset "utf-8 dictionary" begin
    d = SymSpell()

    @test push!(d, "привет", 10)
end

@testset "dictionary load" begin
    d = SymSpell(count_threshold = 2)
    update!(d, joinpath(@__DIR__, "..", "assets", "test_dict.txt"))

    @test d.words[first(d.deletes["key"])] == ("key", 10)
    @test d.below_threshold_words["sad"] == 1
    @test length(d.words) == 3
end
end # module
