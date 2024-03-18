module GooSlicingFiles

if !isdefined(Base, :get_extension)
    using Requires
end

using ColorTypes
using FixedPointNumbers
using Dates

import Base: size, getindex, convert

export GooSlicingFile, GooHeader, GooImage, GooLayer
export read_goo_slicing, add_goo_slicing_format

const MAGIC = UInt8[0x07, 0x00, 0x00, 0x00, 0x44, 0x4c, 0x50, 0x00]
const MAGIC_STR = String(MAGIC)
const ENDING = UInt8[0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x44, 0x4c, 0x50, 0x00]
const ENDING_STR = String(ENDING)

include("utilities.jl")

struct ExposureDelayMode{T} end

const DelayStatic = ExposureDelayMode{:Static}()
const DelayTurnOff = ExposureDelayMode{:TurnOff}()

mutable struct PrintSettings
    exposure_time::Float32 # [s]
    turn_off_time::Float32 # [s]
    before_lift_time::Float32 # [s]
    after_lift_time::Float32 # [s]
    after_retract_time::Float32 # [s]
    lift_distance::Float32 # [mm]
    lift_speed::Float32 # [mm/min]
    lift_distance_2::Float32 # [mm]
    lift_speed_2::Float32 # [mm/min]
    retract_distance::Float32 # [mm]
    retract_speed::Float32 # [mm/min]
    retract_distance_2::Float32 # [mm]
    retract_speed_2::Float32 # [mm/min]
    light_pwm::Int # in 0-255
end

mutable struct GooHeader
    version::String
    magic_tag::String
    software_info::String
    software_version::String
    file_time::DateTime
    printer_name::String
    printer_type::String
    profile_name::String
    antialiasing_level::Int
    gray_level::Int
    blur_level::Int
    small_preview_image::Matrix{RGB{N0f8}}
    big_preview_image::Matrix{RGB{N0f8}}
    total_layers::Int
    x_resolution::Int # pixels
    y_resolution::Int # pixels
    x_mirror::Bool
    y_mirror::Bool
    x_size_of_platform::Float32 # [mm]
    y_size_of_platform::Float32 # [mm]
    z_size_of_platform::Float32 # [mm]
    layer_thickness::Float32 # [mm]
    expusure_delay_mode::ExposureDelayMode
    bottom_settings::PrintSettings
    bottom_layers::Int
    common_settings::PrintSettings
    advance_mode::Bool
    printing_time::Int # [s]
    total_volume::Float32 # [mm^3]
    total_weight::Float32 # [g]
    total_price::Float32
    price_unit::String
    offset_of_layer_content::Int
    gray_scale_level::Int
end

struct GooImage{G<:AbstractGray,H,W} <: AbstractMatrix{G}
    data::Vector{UInt8}
    x_mirror::Bool
    y_mirror::Bool
    function GooImage{G,H,W}(
        data::AbstractVector{UInt8};
        x_mirror = false,
        y_mirror = false) where {G<:AbstractGray,H,W}
        new(data, x_mirror, y_mirror)
    end
end

mutable struct GooLayer{G<:AbstractGray,H,W}
    pause_flag::UInt16
    pause_position_z::Float32
    layer_position_z::Float32
    settings::PrintSettings
    image::GooImage{G,H,W}
end

struct GooSlicingFile
    header::GooHeader
    layers::Vector{GooLayer}
end

include("image.jl")

include("read.jl")

function load end
function save end
function add_goo_slicing_format end

@static if !isdefined(Base, :get_extension)
    function __init__()
        @require FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549" include("../ext/GooSlicingFilesFileIOExt.jl")
    end
end

end # module
