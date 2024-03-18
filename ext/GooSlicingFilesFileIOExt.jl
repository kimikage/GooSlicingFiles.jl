module GooSlicingFilesFileIOExt

isdefined(Base, :get_extension) ? (using FileIO) : (using ..FileIO)

using UUIDs
using GooSlicingFiles

function GooSlicingFiles.load(f::File{format"GooSlicing"}; kwargs...)
    open(f, "r") do s
        GooSlicingFiles.load(s, kwargs...)
    end
end

function GooSlicingFiles.load(s::Stream{format"GooSlicing"}; kwargs...)
    read_goo_slicing(stream(s))
end

const MAGIC = (
    vcat(UInt8.(b"V3.0"), GooSlicingFiles.MAGIC)
,)

function GooSlicingFiles.add_goo_slicing_format()
    add_format(
        format"GooSlicing",
        MAGIC,
        ".goo",
        [:GooSlicingFiles => UUID("b8ec2ea3-d517-4854-91d0-702d6cfb9685")]
    )
end

end # module
