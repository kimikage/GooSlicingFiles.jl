function read_preview_image(io::IO, size::Tuple{Int,Int})
    image = Matrix{RGB{N0f8}}(undef, size)
    for y in 1:size[1], x in 1:size[2]
        image[y, x] = rgb565_to_888(ntoh(read(io, UInt16)))
    end
    return image
end

function read_header(io::IO)
    rstr(nb) = String(read(io, nb))
    str(nb) = rstrip(rstr(nb), '\0')
    f32() = reinterpret(Float32, ntoh(read(io, UInt32)))
    i32() = ntoh(read(io, Int32))
    i16() = ntoh(read(io, Int16))
    u16() = ntoh(read(io, UInt16))
    b() = read(io, UInt8) == 0x01

    try
        version = str(4)
        version in ("V3.0",) || @warn "unknown version"
        magic_tag = rstr(8)
        if magic_tag != MAGIC_STR
            error("invalid Magic Tag: $(escape_string(magic_tag))")
        end
        software_info = str(32)
        software_version = str(24)
        file_time = parse_datetime(str(24))
        printer_name = str(32)
        printer_type = str(32)
        profile_name = str(32)
        antialiasing_level = i16()
        gray_level = i16()
        blur_level = i16()
        small_preview_image = read_preview_image(io, (116, 116))
        delim = u16()
        delim === 0x0d0a || error("invalid delimiter after the small preview: $delim")
        big_preview_image = read_preview_image(io, (290, 290))
        delim = u16()
        delim === 0x0d0a || error("invalid delimiter after the big preview: $delim")
        total_layers = i32()
        x_resolution = i16()
        y_resolution = i16()
        x_mirror = b()
        y_mirror = b()
        x_size_of_platform = f32()
        y_size_of_platform = f32()
        z_size_of_platform = f32()
        layer_thickness = f32()
        exposure_time = f32()
        expusure_delay_mode = b() ? DelayStatic : DelayTurnOff
        turn_off_time = f32()
        bottom_before_lift_time = f32()
        bottom_after_lift_time = f32()
        bottom_after_retract_time = f32()
        before_lift_time = f32()
        after_lift_time = f32()
        after_retract_time = f32()
        bottom_exposure_time = f32()
        bottom_layers = i32()
        bottom_lift_distance = f32()
        bottom_lift_speed = f32()
        lift_distance = f32()
        lift_speed = f32()
        bottom_retract_distance = f32()
        bottom_retract_speed = f32()
        retract_distance = f32()
        retract_speed = f32()
        bottom_lift_distance_2 = f32()
        bottom_lift_speed_2 = f32()
        lift_distance_2 = f32()
        lift_speed_2 = f32()
        bottom_retract_distance_2 = f32()
        bottom_retract_speed_2 = f32()
        retract_distance_2 = f32()
        retract_speed_2 = f32()
        bottom_light_pwm = i16()
        light_pwm = i16()
        advance_mode = b()
        printing_time = i32()
        total_volume = f32()
        total_weight = f32()
        total_price = f32()
        price_unit = str(8)
        offset_of_layer_content = i32()
        gray_scale_level = b() ? 256 : 16
        bottom_settings = PrintSettings(
            bottom_exposure_time,
            turn_off_time,
            bottom_before_lift_time,
            bottom_after_lift_time,
            bottom_after_retract_time,
            bottom_lift_distance,
            bottom_lift_speed,
            bottom_lift_distance_2,
            bottom_lift_speed_2,
            bottom_retract_distance,
            bottom_retract_speed,
            bottom_retract_distance_2,
            bottom_retract_speed_2,
            bottom_light_pwm,
        )
        common_settings = PrintSettings(
            exposure_time,
            turn_off_time,
            before_lift_time,
            after_lift_time,
            after_retract_time,
            lift_distance,
            lift_speed,
            lift_distance_2,
            lift_speed_2,
            retract_distance,
            retract_speed,
            retract_distance_2,
            retract_speed_2,
            light_pwm,
        )

        return GooHeader(
            version,
            magic_tag,
            software_info,
            software_version,
            file_time,
            printer_name,
            printer_type,
            profile_name,
            antialiasing_level,
            gray_level,
            blur_level,
            small_preview_image,
            big_preview_image,
            total_layers,
            x_resolution,
            y_resolution,
            x_mirror,
            y_mirror,
            x_size_of_platform,
            y_size_of_platform,
            z_size_of_platform,
            layer_thickness,
            expusure_delay_mode,
            bottom_settings,
            bottom_layers,
            common_settings,
            advance_mode,
            printing_time,
            total_volume,
            total_weight,
            total_price,
            price_unit,
            offset_of_layer_content,
            gray_scale_level,
        )
    catch e
        rethrow(e)
    end
end



function read_layer_content(io::IO, header::GooHeader, ::Type{G}=Gray{N0f8}) where {G<:AbstractGray}
    f32() = reinterpret(Float32, ntoh(read(io, UInt32)))
    i32() = ntoh(read(io, Int32))
    i16() = ntoh(read(io, Int16))
    u16() = ntoh(read(io, UInt16))
    pause_flag = u16()
    pause_position_z = f32()
    layer_position_z = f32()
    layer_exposure_time = f32()
    layer_off_time = f32()
    before_lift_time = f32()
    after_lift_time = f32()
    after_retract_time = f32()
    lift_distance = f32()
    lift_speed = f32()
    lift_distance_2 = f32()
    lift_speed_2 = f32()
    retract_distance = f32()
    retract_speed = f32()
    retract_distance_2 = f32()
    retract_speed_2 = f32()
    light_pwm = i16()
    delim = u16()
    delim == 0x0d0a || error("invalid delimiter at the end of layer definition")
    settings = PrintSettings(
        layer_exposure_time,
        layer_off_time,
        before_lift_time,
        after_lift_time,
        after_retract_time,
        lift_distance,
        lift_speed,
        lift_distance_2,
        lift_speed_2,
        retract_distance,
        retract_speed,
        retract_distance_2,
        retract_speed_2,
        light_pwm,
    )
    nb = i32()
    imagedata = read(io, nb)
    verify_checksum(imagedata)
    H = header.y_resolution
    W = header.x_resolution
    goo_image =
        GooImage{G,H,W}(imagedata, x_mirror=header.x_mirror, y_mirror=header.y_mirror)
    delim = u16()
    delim == 0x0d0a || error("invalid delimiter at the end of layer content")
    return GooLayer{G,H,W}(
        pause_flag,
        pause_position_z,
        layer_position_z,
        settings,
        goo_image
    )
end

function read_goo_slicing(filepath::AbstractString)
    open(filepath, "r") do f
        return read_goo_slicing(f)
    end
end

function read_goo_slicing(io::IO)
    head = position(io)
    header = read_header(io)
    header_length = position(io) - head
    skip(io, header.offset_of_layer_content - header_length)

    if header.gray_scale_level == 16
        G = Gray{N4f4}
    elseif header.gray_scale_level == 256
        G = Gray{N0f8}
    else
        error("unknown gray scale level")
    end
    H = header.y_resolution
    W = header.x_resolution
    layers = Vector{GooLayer{G,H,W}}(undef, header.total_layers)
    for i in 1:length(layers)
        layers[i] = read_layer_content(io, header, G)
    end
    ending = read(io, length(ENDING))
    ending == ENDING || error("invalid ending-string")
    return GooSlicingFile(header, layers)
end