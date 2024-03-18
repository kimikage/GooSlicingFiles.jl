using Test, GooSlicingFiles
using PNGFiles
using ColorTypes
using FixedPointNumbers

julia_goo = joinpath(@__DIR__, "julia.goo")
julia_goo_data = read(julia_goo)


@testset "read_preview_image" begin
    io = IOBuffer(julia_goo_data)
    seek(io, 0xc2)
    small_preview = GooSlicingFiles.read_preview_image(io, (116, 116))
    PNGFiles.save(joinpath(@__DIR__, "out", "small_preview.png"), small_preview)
    seek(io, 0x69e4)
    big_preview = GooSlicingFiles.read_preview_image(io, (290, 290))
    PNGFiles.save(joinpath(@__DIR__, "out", "big_preview.png"), big_preview)
end

@testset "read_header" begin
    io = IOBuffer(julia_goo_data)
    h = GooSlicingFiles.read_header(io)
    @test h isa GooHeader

    @test h.version == "V3.0"
    @test h.magic_tag == "\x7\0\0\0DLP\0"
    # @test h.software_info == "GooSlicingFiles.jl"
    # @test h.software_version == "v0.1.0"
    # @test h.file_time == DateTime()
    # @test printer_name == "Julia 9K Ultra"
    @test h.profile_name == "Standard Resin_Normal"
    @test h.x_resolution == 8520
    @test h.y_resolution == 4320
    @test h.x_size_of_platform === 18 * 8520 * 1f-3
    @test h.y_size_of_platform === 18 * 4320 * 1f-3
    @test h.z_size_of_platform === 165.0f0

    for fld in fieldnames(typeof(h))
        v = getfield(h, fld)
        if v isa Number
            @show fld, v
        end
    end
end

@testset "read_layer_content" begin
    io = IOBuffer(julia_goo_data)
    header = GooSlicingFiles.read_header(io)
    seek(io, header.offset_of_layer_content)
    layer1 = GooSlicingFiles.read_layer_content(io, header)
    @test layer1 isa GooLayer
end

@testset "read_goo_slicing" begin
    io = IOBuffer(julia_goo_data)
    goo = read_goo_slicing(io)
    @test goo isa GooSlicingFile
    @test goo.header isa GooHeader
    @test goo.header.total_layers == 70
    @test all(l -> l isa GooLayer, goo.layers)
end