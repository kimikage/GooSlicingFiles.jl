
function rgb565_to_888(u16::UInt16)
    r = (muladd(u16 >> 0xb, 0x083a, 0x0080)) >> 0x8 % UInt8
    g = (muladd(u16 << 0x5 >> 0xa, 0x040c, 0x0084)) >> 0x8 % UInt8
    b = (muladd(u16 & 0x001f, 0x083a, 0x0080)) >> 0x8 % UInt8
    return RGB{N0f8}(reinterpret.(N0f8, (r, g, b))...)
end

function parse_datetime(str::AbstractString)
    num = tryparse(Int64, str)
    if num isa Int64
        dmin = round(now() - now(UTC), Minute)
        time = unix2datetime(num) + dmin
        2000 <= year(time) <= 2100 && return time
    end

    time = tryparse(DateTime, str)
    time isa DateTime && return time
    spstr = split(str)
    if length(spstr) == 2
        d = tryparse(Date, spstr[1])
        t = tryparse(Time, spstr[2])
        d isa Date && t isa Time && return DateTime(d, t,)
    end

    @warn "unknown time format: $str"
    return DateTime(0)
end