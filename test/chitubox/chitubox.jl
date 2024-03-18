using Test, GooSlicingFiles
using PNGFiles

@testset "M4U 0.1mm" begin
    goo = read_goo_slicing(joinpath(@__DIR__, "m4u_0.1_2.5.goo"))
    @test goo isa GooSlicingFile
    header = goo.header
    @test header.software_info == "CHITUBOX Basic v2.0"
    @test header.total_layers == 20
    @test header.x_resolution == 8520
    @test header.y_resolution == 4320
    img = fill(Gray{N0f8}(0), size(goo.layers[1].image))
    for (i, l) in enumerate(goo.layers)
        GooSlicingFiles.decode_image!(img, l.image)
        if get(ENV, "CI", "false") == "false"
            PNGFiles.save(joinpath(@__DIR__, "out", "m4u_0.1_2.5.goo_$(string(i, pad=4)).png"), img)
        end
    end
end