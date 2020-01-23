module TestSymSpell
include("preamble.jl")

@testset "dictionary creation" begin
    d = SymSpell()

    @test push!(d, "a", 2)
    @test d.words == Dict{String, Int}("a" => 2)
    @test isempty(d.below_threshold_words)
    @test d.deletes == Dict{String, Vector{String}}("" => ["a"], "a" => ["a"])

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
    @test d.deletes == Dict{String, Vector{String}}("bc" => ["abc"], "ac" => ["abc"], "ab" => ["abc"], "abc" => ["abc"])

    push!(d, "abd", 100)
    @test d.deletes["ab"] == ["abc", "abd"]
end

@testset "utf-8 dictionary" begin
    d = SymSpell()

    @test push!(d, "привет", 10)
end

@testset "dictionary load" begin
    d = SymSpell(count_threshold = 2)
    update!(d, joinpath(@__DIR__, "..", "assets", "test_dict.txt"))

    @test d.words["key"] == 10
    @test d.below_threshold_words["sad"] == 1
    @test length(d.words) == 3
end
end # module
