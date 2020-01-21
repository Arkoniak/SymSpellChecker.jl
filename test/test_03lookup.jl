module TestLookup

include("preamble.jl")

using SymSpell: SuggestItem, delete_in_suggestion_prefix, Verbosity,
    VerbosityALL, VerbosityTOP, VerbosityCLOSEST

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

@testset "words with shared prefix should retain counts" begin
    d = Dictionary()
    push!(d, "pipe", 5)
    push!(d, "pips", 10)

    result = lookup(d, "pipe", verbosity = VerbosityALL, max_edit_distance = 1)
    @test length(result) == 2
    @test result[1].phrase == "pipe"
    @test result[1].count == 5
    @test result[2].phrase == "pips"
    @test result[2].count == 10

    result = lookup(d, "pips", verbosity = VerbosityALL, max_edit_distance = 1)
    @test length(result) == 2
    @test result[1].phrase == "pips"
    @test result[1].count == 10
    @test result[2].phrase == "pipe"
    @test result[2].count == 5

    result = lookup(d, "pip", verbosity = VerbosityALL, max_edit_distance = 1)
    @test length(result) == 2
    @test result[1].phrase == "pips"
    @test result[1].count == 10
    @test result[2].phrase == "pipe"
    @test result[2].count == 5
end

@testset "verbosity should control lookup results" begin
    d = Dictionary()
    push!(d, "steam", 1)
    push!(d, "steams", 2)
    push!(d, "steem", 3)

    result = lookup(d, "steems", verbosity = VerbosityTOP, max_edit_distance = 2)
    @test length(result) == 1

    result = lookup(d, "steems", verbosity = VerbosityCLOSEST, max_edit_distance = 2)
    @test length(result) == 2

    result = lookup(d, "steems", verbosity = VerbosityALL, max_edit_distance = 2)
    @test length(result) == 3
end

@testset "lookup should return most frequent" begin
    d = Dictionary()
    push!(d, "steama", 4)
    push!(d, "steamb", 6)
    push!(d, "steamc", 2)

    result = lookup(d, "stream", verbosity = VerbosityTOP, max_edit_distance = 2)
    @test length(result) == 1
    @test result[1].phrase == "steamb"
    @test result[1].count == 6
end

@testset "lookup should find exact match" begin
    d = Dictionary()
    push!(d, "steama", 4)
    push!(d, "steamb", 6)
    push!(d, "steamc", 2)

    result = lookup(d, "streama", verbosity = VerbosityTOP, max_edit_distance = 2)
    @test length(result) == 1
    @test result[1].phrase == "steama"
end

@testset "lookup should not return non word delete" begin
    d = Dictionary(count_threshold = 10)
    push!(d, "pawn", 10)
    result = lookup(d, "paw", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0

    result = lookup(d, "awn", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0
end

@testset "lookup should not return low count word" begin
    d = Dictionary(count_threshold = 10)
    push!(d, "pawn", 1)
    result = lookup(d, "pawn", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0
end

@testset "lookup should not return low count word that are also delete word" begin
    d = Dictionary(count_threshold = 10)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    result = lookup(d, "flam", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0
end

@testset "lookup max edit distance too large" begin
    d = Dictionary(count_threshold = 10)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    @test_throws ArgumentError lookup(d, "flam", verbosity = VerbosityTOP, max_edit_distance = 3)
end

@testset "lookup include unknown" begin
    d = Dictionary(count_threshold = 10)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    result = lookup(d, "flam", verbosity = VerbosityTOP, max_edit_distance = 0, include_unknown = true)
    @test length(result) == 1
    @test result[1].phrase == "flam"
end

@testset "lookup avoid exact match early exit" begin
    max_edit_distance = 2
    d = Dictionary(count_threshold = 10, max_dictionary_edit_distance = max_edit_distance)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    result = lookup(d, "24th", verbosity = VerbosityALL, max_edit_distance = max_edit_distance,
        ignore_token = r"\d{2}\w*\b")
    @test length(result) == 1
    @test result[1].phrase == "24th"
end

@testset "no duplicates in lookup" begin
    d = Dictionary()
    push!(d, "bank", 10)
    result = lookup(d, "xbank", verbosity = VerbosityALL)

    @test length(result) == 1
end
end # module
