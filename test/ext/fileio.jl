using Test, GooSlicingFiles

julia_goo = joinpath(@__DIR__, "..", "julia.goo")

@testset "w/o FileIO" begin
    @test length(methods(GooSlicingFiles.load)) == 0
end

using FileIO

@testset "w/ FileIO" begin
    @test length(methods(GooSlicingFiles.load)) == 2
end

module KPT
    import FileIO: @format_str, File

    function load(::File{format"GOO"})
        return :KPT
    end
end

add_format(format"GOO", "CCmF", ".goo", [KPT])

@testset "before registration" begin
    @test load(julia_goo) == :KPT
end

@testset "after registration" begin
    add_goo_slicing_format()

    FileIO.query(julia_goo)

    julia_goo_from_file = load(julia_goo)
    @test julia_goo_from_file isa GooSlicingFile
end
