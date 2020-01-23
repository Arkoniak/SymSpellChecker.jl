module TestUTF8

include("preamble.jl")

using SymSpellChecker: add_edits!, delete_in_suggestion_prefix

@testset "add_edits! should generate correct delete sequence for ascii" begin
    considered_deletes = Set{String}()
    candidates = Set{String}()
    candidate = "world"
    candidate_len = length(candidate)
    add_edits!(considered_deletes, candidates, candidate, candidate_len)
    @test length(candidates) == 5
    @test candidates == Set(["orld", "wrld", "wold", "word", "worl"])
end

@testset "add_edits! should generate correct delete sequence for utf-8" begin
    considered_deletes = Set{String}()
    candidates = Set{String}()
    candidate = "земля"
    candidate_len = length(candidate)
    add_edits!(considered_deletes, candidates, candidate, candidate_len)
    @test length(candidates) == 5
    @test candidates == Set(["емля", "змля", "зеля", "земя", "земл"])
end

@testset "delete should be in suggestion prefix" begin
    @test delete_in_suggestion_prefix("bc", "bc", 7)
    @test delete_in_suggestion_prefix("xyz", "axbyczkkkkkkkkkk", 7)
    @test delete_in_suggestion_prefix("xyzmmmmm", "xyzkkkkkkkkkk", 3)
    @test !delete_in_suggestion_prefix("xyz", "axbykkkkkkkkkk", 7)

    @test delete_in_suggestion_prefix("змл", "земля", 5)
end

end # module
