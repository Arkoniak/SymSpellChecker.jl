module TestLookup

include("preamble.jl")

using SymSpellChecker: SuggestItem, Verbosity,
    VerbosityALL, VerbosityTOP, VerbosityCLOSEST

@testset "basic lookup" begin
    d = SymSpell()

    push!(d, "a", 5)
    push!(d, "bc", 2)

    @test_throws ArgumentError lookup(d, "xyz", max_edit_distance = 3)

    @test isempty(lookup(d, "qwerty"))
    @test lookup(d, "qwerty", include_unknown = true) == [SuggestItem("qwerty", 3, 0)]
    @test lookup(d, "bc") == [SuggestItem("bc", 0, 2)]
    @test lookup(d, "qwe", max_edit_distance = 0, include_unknown = true) == [SuggestItem("qwe", 1, 0)]
    @test lookup(d, "abc", max_edit_distance = 1) == [SuggestItem("bc", 1, 2)]

    @test first(d["abc"]) == "bc"
end

@testset "basic options" begin
    d = SymSpell()

    push!(d, "a", 5)
    push!(d, "bc", 2)

    set_options!(d, include_unknown = true)
    @test first(d["qwerty"]) == "qwerty"

    set_options!(d, include_unknown = false, transfer_casing = true, max_edit_distance = 2)
    @test first(d["Bde"]) == "Bc"

    @test length(lookup(d, "ac", verbosity = "all")) == 2
end

@testset "words with shared prefix should retain counts" begin
    d = SymSpell()
    push!(d, "pipe", 5)
    push!(d, "pips", 10)

    result = lookup(d, "pipe", verbosity = VerbosityALL, max_edit_distance = 1)
    @test length(result) == 2
    @test result[1].term == "pipe"
    @test result[1].count == 5
    @test result[2].term == "pips"
    @test result[2].count == 10

    result = lookup(d, "pips", verbosity = VerbosityALL, max_edit_distance = 1)
    @test length(result) == 2
    @test result[1].term == "pips"
    @test result[1].count == 10
    @test result[2].term == "pipe"
    @test result[2].count == 5

    result = lookup(d, "pip", verbosity = VerbosityALL, max_edit_distance = 1)
    @test length(result) == 2
    @test result[1].term == "pips"
    @test result[1].count == 10
    @test result[2].term == "pipe"
    @test result[2].count == 5
end

@testset "verbosity should control lookup results" begin
    d = SymSpell()
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
    d = SymSpell()
    push!(d, "steama", 4)
    push!(d, "steamb", 6)
    push!(d, "steamc", 2)

    result = lookup(d, "stream", verbosity = VerbosityTOP, max_edit_distance = 2)
    @test length(result) == 1
    @test result[1].term == "steamb"
    @test result[1].count == 6
end

@testset "lookup should find exact match" begin
    d = SymSpell()
    push!(d, "steama", 4)
    push!(d, "steamb", 6)
    push!(d, "steamc", 2)

    result = lookup(d, "streama", verbosity = VerbosityTOP, max_edit_distance = 2)
    @test length(result) == 1
    @test result[1].term == "steama"
end

@testset "lookup should not return non word delete" begin
    d = SymSpell(count_threshold = 10)
    push!(d, "pawn", 10)
    result = lookup(d, "paw", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0

    result = lookup(d, "awn", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0
end

@testset "lookup should not return low count word" begin
    d = SymSpell(count_threshold = 10)
    push!(d, "pawn", 1)
    result = lookup(d, "pawn", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0
end

@testset "lookup should not return low count word that are also delete word" begin
    d = SymSpell(count_threshold = 10)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    result = lookup(d, "flam", verbosity = VerbosityTOP, max_edit_distance = 0)
    @test length(result) == 0
end

@testset "lookup max edit distance too large" begin
    d = SymSpell(count_threshold = 10)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    @test_throws ArgumentError lookup(d, "flam", verbosity = VerbosityTOP, max_edit_distance = 3)
end

@testset "lookup include unknown" begin
    d = SymSpell(count_threshold = 10)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    result = lookup(d, "flam", verbosity = VerbosityTOP, max_edit_distance = 0, include_unknown = true)
    @test length(result) == 1
    @test result[1].term == "flam"
end

@testset "lookup avoid exact match early exit" begin
    max_edit_distance = 2
    d = SymSpell(count_threshold = 10, max_dictionary_edit_distance = max_edit_distance)
    push!(d, "flame", 20)
    push!(d, "flam", 1)
    result = lookup(d, "24th", verbosity = VerbosityALL, max_edit_distance = max_edit_distance,
        ignore_token = r"\d{2}\w*\b")
    @test length(result) == 1
    @test result[1].term == "24th"
end

@testset "no duplicates in lookup" begin
    d = SymSpell()
    push!(d, "bank", 10)
    result = lookup(d, "xbank", verbosity = VerbosityALL)

    @test length(result) == 1
end

@testset "shouldn't switch to far away words" begin
    d = SymSpell()
    push!(d, "border", 200)
    push!(d, "bored", 40)
    push!(d, "board", 50)
    push!(d, "for", 100)
    result = lookup(d, "bord")

    @test result[1].term == "board"
end

@testset "should correctly check words at the prefix edge" begin
    d = SymSpell(max_dictionary_edit_distance = 1, prefix_length = 5)
    push!(d, "called", 10)

    result = lookup(d, "callvd", verbosity = VerbosityTOP)
    @test length(result) > 0
    @test result[1].term == "called"

    d = SymSpell(max_dictionary_edit_distance = 1, prefix_length = 5)
    push!(d, "calleds", 10)
    result = lookup(d, "callvds", verbosity = VerbosityTOP)
    @test length(result) > 0
    @test result[1].term == "calleds"

    d = SymSpell(max_dictionary_edit_distance = 1, prefix_length = 5)
    push!(d, "calleds", 10)
    result = lookup(d, "callvdx", verbosity = VerbosityTOP)
    @test length(result) == 0
end

@testset "should correctly search utf keywords" begin
    d = SymSpell(max_dictionary_edit_distance = 1)

    push!(d, "привет", 10)
    @test length(d["прифет"]) > 0
    @test length(d["пфетик"]) == 0
end

end # module
