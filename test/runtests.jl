using SymSpell: get_opcodes, transfer_casing_for_similar_text, transfer_casing_for_matching_text
using Test

@testset "SymSpell" begin
    @testset "Lookup" begin
        @testset "opcode" begin
            @test get_opcodes("a", "") == [("delete", 1, 1, 1, 0)]
            @test get_opcodes("", "a") == [("insert", 1, 0, 1, 1)]
            @test get_opcodes("a", "b") == [("replace", 1, 1, 1, 1)]
            @test get_opcodes("a", "bc") == [("replace", 1, 1, 1, 2)]
            @test get_opcodes("a", "ab") == [("equal", 1, 1, 1, 1), ("insert", 2, 1, 2, 2)]
            @test get_opcodes("a", "bac") == [("insert", 1, 0, 1, 1), ("equal", 1, 1, 2, 2), ("insert", 2, 1, 3, 3)]
            @test get_opcodes("ac", "abc") == [("equal", 1, 1, 1, 1), ("insert", 2, 1, 2, 2), ("equal", 2, 2, 3, 3)]
            @test get_opcodes("qabxcd", "abycdf") == [("delete", 1, 1, 1, 0), ("equal", 2, 3, 1, 2),
                                                                ("replace", 4, 4, 3, 3), ("equal", 5, 6, 4, 5),
                                                                ("insert", 7, 6, 6, 6)]
        end

        @testset "transfer_casing" begin
            text_w_casing  = "Haw is the eeather in New York?"
            text_wo_casing = "how is the weather in new york?"
            @test transfer_casing_for_matching_text(text_w_casing, text_wo_casing) == "How is the weather in New York?"

            text_w_casing = "Haaw is the weeather in New York?"
            text_wo_casing = "how is the weather in new york?"
            @test transfer_casing_for_similar_text(text_w_casing, text_wo_casing) == "How is the weather in New York?"
        end
    end
end
