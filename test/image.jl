using Test, GooSlicingFiles
using ColorTypes
using FixedPointNumbers
using PNGFiles

julia_goo = joinpath(@__DIR__, "julia.goo")
julia_goo_file = read_goo_slicing(julia_goo)

@testset "verify_checksum" begin
    @test GooSlicingFiles.verify_checksum([0x55, 0xa5, 0x5a])
    @test_throws Exception GooSlicingFiles.verify_checksum([0x66, 0xa5, 0x5a])
    @test_throws Exception GooSlicingFiles.verify_checksum([0x55, 0xa5, 0xa5])
end

@testset "read_chunk_length" begin
    rcl = GooSlicingFiles.read_chunk_length
    @test rcl(0x01, [0x01], 2) == (Int(0x1), 2)
    @test rcl(0xcf, [0xcf], 2) == (Int(0xf), 2)
    @test rcl(0x51, [0x51, 0xaa, 0x32], 3) == (Int(0x321), 4)
    @test rcl(0x21, [0x21, 0x54, 0x32], 2) == (Int(0x54321), 4)
    @test rcl(0xf1, [0xf1, 0x76, 0x54, 0x32], 2) == (Int(0x7654321), 5)
end

@testset "decode_image!" begin
    header = julia_goo_file.header

    image = fill(Gray{N0f8}(1), header.y_resolution, header.x_resolution)

    GooSlicingFiles.decode_image!(image, julia_goo_file.layers[1].image)

    @test all(image[1, :] .== Gray{N0f8}(0))
    @test any(image[2000, :] .== Gray{N0f8}(1))

    PNGFiles.save(joinpath(@__DIR__, "out", "julia.goo_0001.png"), image)

    fill!(image, Gray{N0f8}(1))
    GooSlicingFiles.decode_image!(image, julia_goo_file.layers[70].image)

    @test all(image[1, :] .== Gray{N0f8}(0))
    @test any(image[2000, :] .== Gray{N0f8}(1))

    PNGFiles.save(joinpath(@__DIR__, "out", "julia.goo_0070.png"), image)

end

@testset "decode_image_data!" begin
    image = fill(Gray{N0f8}(1), 50, 100)
    @testset "Blacks" begin
        blacks = UInt8[
            0x55,
            # 50 * 100 = 0b00000001_00111000_1000
            0b00_10_1000,
            0b00000001,
            0b00111000,
            0x00
        ]
        blacks[end] = ~sum(blacks[2:end]) % UInt8
        GooSlicingFiles.decode_image_data!(image, blacks)
        @test all(g -> g === Gray{N0f8}(0), image)
    end

    @testset "Grays" begin
        grays = UInt8[
            0x55,
            # 10 = 0b1010
            0b01_00_1010,
            0x11, # gray
            # 90 = 0b00000101_1010
            0b01_01_1010,
            0x99, # gray
            0b00000101,
            # 49 * 100 = 0b00000001_00110010_0100
            0b01_10_0100,
            0xcc, # gray
            0b00000001,
            0b00110010,
            0x00
        ]
        grays[end] = ~sum(grays[2:end]) % UInt8
        GooSlicingFiles.decode_image_data!(image, grays)
        PNGFiles.save(joinpath("out", "grays.png"), image)
    end

    @testset "Diff. Grays" begin
        dgrays = UInt8[
            0x55,
            # (0x00), 8 = 0b1000
            0b00_00_1000,
            # +9 (0x09)
            0b10_00_1001,
            # +7 (0x10)
            0b10_00_0111,
            # +15 (0x1f), 90 = 0b01011010
            0b10_01_1111,
            0b01011010,
            # +15 (0x2e), 200 = 0b11001000
            0b10_01_1111,
            0b11001000,
            # (0xff), 44 * 100 = 0b00000001_00010011_0000
            0b11_10_0000,
            0b00000001,
            0b00010011,
            # -15 (0xf0), 200 = 0b11001000
            0b10_11_1111,
            0b11001000,
            # -14 (0xe2), 90 = 0b01011010
            0b10_11_1110,
            0b01011010,
            # -12 (0xd6)
            0b10_10_1100,
            # -5 (0xd0)
            0b10_10_0101,
            # (0x00), 8 = 0b1000
            0b00_00_1000,
            0x00
        ]
        dgrays[end] = ~sum(dgrays[2:end]) % UInt8
        GooSlicingFiles.decode_image_data!(image, dgrays)
        PNGFiles.save(joinpath("out", "dgrays.png"), image)
    end
end

@testset "getindex" begin
    bw = UInt8[
        0x55,
        0b00_00_0100,
        0b11_00_0100,
        0b00_11_0111
    ]
    goo_image = GooImage{Gray{N0f8},2,4}(bw)
    mat_image = Gray{N0f8}[0 0 0 0; 1 1 1 1]

    @test goo_image[1, 2] === mat_image[1, 2]
    @test all(goo_image[1:2, :] .=== mat_image[1:2, :])
end

@testset "convert" begin
    bw = UInt8[
        0x55,
        0b00_00_0100,
        0b11_00_0100,
        0b00_11_0111 # checksum
    ]
    goo_image = GooImage{Gray{N0f8},2,4}(bw)
    mat_image = Gray{N0f8}[0 0 0 0; 1 1 1 1]

    mat = convert(Matrix, goo_image)
    @test mat isa Matrix{Gray{N0f8}}
    @test mat == mat_image

    matg = convert(Matrix{Gray}, goo_image)
    @test matg isa Matrix{Gray}
    @test !(matg isa Matrix{Gray{N0f8}})
    @test all(matg .== mat_image)

    matg8 = convert(Matrix{Gray{N0f8}}, goo_image)
    @test matg8 isa Matrix{Gray{N0f8}}
    @test matg8 == mat_image

    matgf = convert(Matrix{Gray{Float32}}, goo_image)
    @test matgf isa Matrix{Gray{Float32}}
    @test all(matgf .== mat_image)
end
