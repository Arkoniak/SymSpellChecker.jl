module TestDictionary
include("preamble.jl")

@testset "dictionary creation" begin
    d = Dictionary()

    @test push!(d, "a", 2)
    @test d.words == Dict{String, Int}("a" => 2)
    @test isempty(d.below_threshold_words)
    @test d.deletes == Dict{String, Vector{String}}("" => ["a"], "a" => ["a"])

    push!(d, "bc", 2)
    @test d.max_length == 2

    d = Dictionary(count_threshold = 2)
    push!(d, "a", 100)
    push!(d, "bc", 100)
    push!(d, "c", 1)
    @test length(d.words) == 2
    @test length(d.below_threshold_words) == 1

    push!(d, "c", 1)
    @test length(d.words) == 3
    @test length(d.below_threshold_words) == 0
end

@testset "dictionary load" begin
    d = Dictionary(count_threshold = 2)
    update!(d, joinpath(@__DIR__, "..", "assets", "test_dict.txt"))

    @test d.words["key"] == 10
    @test d.below_threshold_words["sad"] == 1
    @test length(d.words) == 3
end
end # module
