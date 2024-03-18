using Test, GooSlicingFiles

@testset "Utilities" begin
    include("utilities.jl")
end
@testset "Read" begin
    include("read.jl")
end
@testset "Image" begin
    include("image.jl")
end

@testset "Chitubox" begin
    include("chitubox/chitubox.jl")
end

@testset "ext FileIO" begin
    include("ext/fileio.jl")
end
