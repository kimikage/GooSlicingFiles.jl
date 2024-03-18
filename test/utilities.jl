using Test, GooSlicingFiles
using ColorTypes
using FixedPointNumbers
using Dates

@testset "_rgb565_to_888" begin
    conv = GooSlicingFiles.rgb565_to_888
    #            RRRRRGGGGGGBBBBB
    @test conv(0b0000000000000000) === RGB{N0f8}(0 / 31, 0 / 63, 0 / 31)
    @test conv(0b0000100001100111) === RGB{N0f8}(1 / 31, 3 / 63, 7 / 31)
    @test conv(0b1111011110011000) === RGB{N0f8}(30 / 31, 60 / 63, 24 / 31)
    @test conv(0b1111111111111111) === RGB{N0f8}(31 / 31, 63 / 63, 31 / 31)
end

@testset "parse_datetime" begin
    p = GooSlicingFiles.parse_datetime
    @test p("2023-04-05 12:34:56") === DateTime(2023, 4, 5, 12, 34, 56)
    @test abs(p("1732050807") - DateTime(2024, 11, 19, 21, 13, 27)) < Hour(13)
end