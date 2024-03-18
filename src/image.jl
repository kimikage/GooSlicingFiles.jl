
struct GooImageInspector{G<:AbstractGray} <: AbstractMatrix{G}
    height::Int
    width::Int
    threshold::G
    top::Int
    left::Int
    bottom::Int
    right::Int
    count::Int
end

Base.size(gi::GooImageInspector) = (gi.height, gi.width)


Base.size(::GooImage{G,H,W}) where {G,H,W} = (H, W)

function Base.getindex(goo_image::GooImage{G}, inds...) where {G<:AbstractGray}
    return getindex(_convert(Matrix{G}, goo_image), inds...)
end

function Base.convert(::Type{M}, goo_image::GooImage) where {M<:AbstractMatrix}
    return _convert(M, goo_image)
end

function Base.convert(::Type{M}, goo_image::GooImage) where {M<:Matrix}
    return _convert(M, goo_image)
end

function _convert(::Type{M}, goo_image::GooImage{G}) where {M<:GooImage,G<:AbstractGray}
    # TODO: add size checking
    return goo_image
end

function _convert(::Type{M},
    goo_image::GooImage{G}) where {M<:AbstractMatrix,G<:AbstractGray}
    mat = _convert(Matrix{G}, goo_image)
    Matrix{G} <: M && return mat
    return convert(M, mat)
end

function _convert(::Type{Matrix{G}},
    goo_image::GooImage{G,H,W}) where {G<:AbstractGray,H,W}
    data = goo_image.data
    io = IOBuffer(data)
    image = Matrix{G}(undef, H, W)
    decode_image_data!(io, image, length(data))
    return image
end


function decode_image!(dest::Matrix{G}, src::GooImage{G}) where {G<:AbstractGray}
    return decode_image_data!(dest, src.data, src.x_mirror, src.y_mirror)
end


function verify_checksum(data::AbstractVector{UInt8})
    magic = first(data)
    magic === 0x55 || error("invalid magic number: $magic")
    checksum = reduce(+, data; init=-0x55)
    if checksum != 0xff
        checksum_cmp = data[end]
        checksum_res = checksum - checksum_cmp
        error("checksum error. sum: $(repr(checksum_res)), comp.: $(repr(checksum_cmp))")
    end
    return true
end

function read_chunk_length(b0::UInt8, data::AbstractVector{UInt8}, i::Int)
    n = (b0 >> 0x4) & 0x3
    cl0 = b0 & 0xf
    cl = 0
    for k in 0x01:n
        cl = (cl << 8) | data[i+k-1]
    end
    return cl << 4 + cl0, i + n
end

function put_pixel(image::AbstractMatrix{G}, itr, it, gray::G, n::Int) where {G}
    for i in 1:n
        @inbounds x, y = it[1]
        @inbounds image[y, x] = gray
        @inbounds it = iterate(itr, it[2])
    end
    return it
end

function decode_image_data!(image::AbstractMatrix{G}, data::AbstractVector{UInt8};
    x_mirror=false, y_mirror=false) where {T,G<:AbstractGray{T}}
    decode_image_data!(image, data, x_mirror, y_mirror)
end

function decode_image_data!(image::AbstractMatrix{G}, data::AbstractVector{UInt8},
    x_mirror::Bool, y_mirror::Bool) where {T,G<:AbstractGray{T}}

    verify_checksum(data)

    rt, rb = firstindex(image, 1), lastindex(image, 1)
    rl, rr = firstindex(image, 2), lastindex(image, 2)

    xr = x_mirror ? (rr:-1:rl) : (rl:rr)
    yr = y_mirror ? (rb:-1:rt) : (rt:rb)

    itr = Iterators.product(xr, yr) # the image data of Goo is row-major.
    it = iterate(itr)

    i = firstindex(data) + 1
    prev = 0x00
    done = false
    while i < lastindex(data)
        b0 = data[i]
        i += 1
        if b0 & 0b11_000000 === 0b10_000000 # 0x80:0xbf
            # This chunk contain the diff value from the previous pixel
            clen = 1
            if b0 & 0b01_0000 === 0b01_0000
                clen = Int(data[i])
                i += 1
            end
            if b0 & 0b10_0000 === 0b10_0000
                gray = prev - (b0 & 0xf)
            else
                gray = prev + (b0 & 0xf)
            end
        else
            gray = reinterpret(UInt8, oneunit(T))
            if b0 & 0b11_000000 === 0b00_000000 # 0x00:0x3f
                # This chunk contain all 0x0 pixels
                gray = 0x00
            elseif b0 & 0b11_000000 === 0b01_000000 # 0x40:0x7f
                # This chunk contain the value of gray between 0x1 to 0xfe
                gray = data[i]
                i += 1
            else # 0xc0:0xff
                # This chunk contain all 0xff pixels
            end
            clen, i = read_chunk_length(b0, data, i)
        end
        g = G(reinterpret(T, gray))
        itn = put_pixel(image, itr, it, g, clen)
        if itn === nothing
            done = true
            break
        end
        it = itn
        prev = gray
    end
    if i != lastindex(data) || !done
        error("unexpected termination")
    end
end

function decode_image_data!(io::IO, image::Matrix{G},
    nb::Integer=0) where {T,G<:AbstractGray{T}}
    if nb > 0
        return decode_image_data!(image, read(io, nb))
    end
    error("streaming decoding is not supported.")
end