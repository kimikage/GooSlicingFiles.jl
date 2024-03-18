using Meshes

assetspath(filename) = joinpath(@__DIR__, "src", "assets", filename)

write_obj(io::IO, mesh::Mesh) = write_obj(io, [mesh])

function write_obj(io::IO, meshes::AbstractVector{<:Mesh})
    ofs = [0]
    for mesh in meshes
        for v in vertices(mesh)
            x, y, z = round.(coordinates(v), digits=3)
            println(io, "v $x $z $(-y)") # z-up -> y-up
        end
        push!(ofs, ofs[end] + length(vertices(mesh)))
    end
    for (i, mesh) in enumerate(meshes)
        println(io, "g obj$i")
        offset = ofs[i]
        for f in elements(topology(mesh))
            inds = indices(f) .+ offset
            println(io, "f ", join(inds, " "))
        end
    end
end

function generate_base()
    local vertices = Point3[]
    local faces = Connectivity[]

    v(x, y, z) = push!(vertices, Point3(x, y, z))
    f(v1, v2, v3) = push!(faces, connect((v1, v2, v3)))
    f(v1, v2, v3, v4) = push!(faces, connect((v1, v2, v3, v4)))

    local rc = 9.0 # rounding radius of the 4 corners
    local re = 1.5 # rounding radius of the top edges

    local hx = 72 * 0.5 # half width
    local hy = 45 * 0.5 # half length
    local fz = 3.0 # height

    local cx = hx - rc
    local cy = hy - rc

    local d = 64
    local d3 = d + 3
    local stride = d3 * 4

    local de = 16

    local gd = 0.1

    function arc(orth, z, r)
        acx = (cx, -cx, -cx, cx)[orth]
        acy = (cy, cy, -cy, -cy)[orth]
        ex = (r, gd, -r, -gd)[orth]
        ey = (-gd, r, gd, -r)[orth]
        v(acx + ex, acy + ey, z) # guard
        for phi in 0:d
            ey, ex = sincospi((phi / d + (orth - 1)) * 0.5) .* r
            v(acx + ex, acy + ey, z)
        end
        ex = (-gd, -r, gd, r)[orth]
        ey = (r, -gd, -r, gd)[orth]
        v(acx + ex, acy + ey, z) # guard
    end

    arc.(1:4, fz, rc - re - gd)
    for theta in 0:de
        z = re * cospi(theta / de * 0.5) - re + fz
        r = rc - re + re * sinpi(theta / de * 0.5)
        arc.(1:4, z, r)
    end
    for z in (fz - re - gd, gd, 0.0)
        arc.(1:4, z, rc)
    end

    ofsc = (de + 5) * stride

    for z in (fz, 0.0)
        v(cx, cy, z)
        v(-cx, cy, z)
        v(-cx, -cy, z)
        v(cx, -cy, z)
    end


    # top faces
    f(ofsc + 1, ofsc + 2, ofsc + 3, ofsc + 4)
    f(ofsc + 1, 1d3, 1d3 + 1, ofsc + 2)
    f(ofsc + 2, 2d3, 2d3 + 1, ofsc + 3)
    f(ofsc + 3, 3d3, 3d3 + 1, ofsc + 4)
    f(ofsc + 4, 4d3, 4d3 + 1, ofsc + 1)

    for orth in 1:4
        ofs = (orth - 1) * d3
        for phi in (ofs+1):(ofs+d+2)
            f(ofsc + orth, phi, phi + 1)
        end
    end

    # side faces
    for theta in 0:(de+3)
        for orth in 1:4
            ofs = (orth - 1) * d3 + stride * theta
            for phi in (ofs+1):(ofs+d+2)
                f(phi + stride, phi + stride + 1, phi + 1, phi)
            end
            phi = ofs + d + 3
            if orth < 4
                f(phi + stride, phi + stride + 1, phi + 1, phi)
            else
                f(phi + stride, phi + 1, phi - stride + 1, phi)
            end
        end
    end

    # bottom faces
    ofs = stride * (de + 4)
    f(ofsc + 8, ofsc + 7, ofsc + 6, ofsc + 5)
    f(ofsc + 6, ofs + 1d3 + 1, ofs + 1d3, ofsc + 5)
    f(ofsc + 7, ofs + 2d3 + 1, ofs + 2d3, ofsc + 6)
    f(ofsc + 8, ofs + 3d3 + 1, ofs + 3d3, ofsc + 7)
    f(ofsc + 5, ofs + 0d3 + 1, ofs + 4d3, ofsc + 8)

    for orth in 1:4
        ofs = (orth - 1) * d3 + stride * (de + 4)
        for phi in (ofs+1):(ofs+d+2)
            f(ofsc + orth + 4, phi + 1, phi)
        end
    end
    return SimpleMesh(vertices, faces)
end

function get_coords_from_svgpath(desc, d, grid=1e-6)
    parse_coord(v) = round(parse(Float64, v) / grid) * grid
    parse_coord(x, y) = (parse_coord(x), -parse_coord(y)) # Y-axis of SVG is downward

    ts = split(desc, r"[ ,]")
    coords = Vec2[]
    i = 1
    prev = ""
    while i < length(ts)
        isnum = tryparse(Float64, ts[i]) !== nothing
        if ts[i] in ("M", "L") || (isnum && prev == "L")
            i += !isnum
            push!(coords, parse_coord(ts[i], ts[i+1]))
            i += 2
            prev = "L"
        elseif ts[i] == "C" || (isnum && prev == "C")
            i += !isnum
            p0 = coords[end]
            p1 = parse_coord(ts[i+0], ts[i+1])
            p2 = parse_coord(ts[i+2], ts[i+3])
            p3 = parse_coord(ts[i+4], ts[i+5])
            if allequal(getindex.((p0, p1, p2, p3), 1)) # workaround for julialogo
                push!(coords, p3)
            else
                for i in 1:d
                    t = i / d
                    u = 1.0 - t
                    p = (p0 .* (u * u * u)) .+
                        (p1 .* (3u * u * t)) .+
                        (p2 .* (3u * t * t)) .+
                        (p3 .* (t * t * t))
                    push!(coords, p)
                end
            end
            i += 6
            prev = "C"
        elseif ts[i] == "Z"
            break
        else
            error("not supported $(ts[i])")
        end
    end
    if coords[1] == coords[end]
        pop!(coords)
    end
    return coords
end

function generate_logo()
    local d = 16

    # width: 320 pt -> 64 mm
    # height: 200 pt -> 40 mm
    scale(v::Real) = v * 64 / 320
    grid = 0.018 / scale(1)
    trans(vec::Vec2) = Vec2(scale(vec[1]), scale(vec[2])) .+ Vec2(-32.004, 19.998)
    flipy(vec::Vec2) = Vec2(vec[1], -vec[2])

    svg = read(assetspath("julia-logo-color.svg"), String)

    ms = collect(eachmatch(r"<path .*d=\"([^\"]+)\"", svg))
    glyphs = split(ms[1][1], r"(?=M)")
    dots = getindex.(ms[2:5], 1)

    j_coords, u_coords, l_coords, i_coords, a1_coords, a2_coords =
        map(desc -> trans.(get_coords_from_svgpath(desc, d, grid)), glyphs)

    j_hubs = trans.(flipy.(Vec2[(45, 190), (35, 195)]))
    u_hubs = trans.(flipy.(Vec2[(100, 155), (115, 160), (135, 150)]))
    l_hubs = trans.(flipy.(Vec2[(180, 150)]))
    i_hubs = trans.(flipy.(Vec2[(215, 150)]))
    a_hubs = trans.(flipy.(Vec2[
        (285, 150), (265, 160), (255, 140), (270, 120), (285, 115), (285, 80), (250, 90)]))

    dot_coords_set = map(desc -> trans.(get_coords_from_svgpath(desc, d)), dots)

    return [
        generate_extruded_mesh(j_coords, j_hubs),
        generate_extruded_mesh(u_coords, u_hubs),
        generate_extruded_mesh(l_coords, l_hubs),
        generate_extruded_mesh(i_coords, i_hubs),
        generate_extruded_mesh((a1_coords, a2_coords), a_hubs),
        generate_extruded_dot_mesh.(dot_coords_set)...,
    ]
end

function generate_extruded_dot_mesh(dot_coords)
    n = length(dot_coords) * 2
    xmin, xmax = extrema(getindex.(dot_coords, 1))
    ymin, ymax = extrema(getindex.(dot_coords, 2))
    cx = (xmin + xmax) * 0.5
    cy = (ymin + ymax) * 0.5
    r = round(((xmax - xmin) + (ymax - ymin)) * 0.25, digits=3)
    coords = [Vec2(sincospi((i - 1) / n * 2.0) .* r .+ (cx, cy)) for i in 1:n]
    return generate_extruded_mesh(coords, [Vec2(cx, cy)])
end

function generate_extruded_mesh(coords, hubs, zrange=(2.999, 7.0))
    generate_extruded_mesh((coords,), hubs, zrange)
end

function generate_extruded_mesh(coordsset::Tuple, hubs, zrange=(2.999, 7.0))
    local vertices = Point3[]
    local faces = Connectivity[]

    v(x, y, z) = push!(vertices, Point3(x, y, z))
    f(v1, v2, v3) = push!(faces, connect((v1, v2, v3)))
    f(v1, v2, v3, v4) = push!(faces, connect((v1, v2, v3, v4)))

    dist(c1, c2) = sqrt((c1[1] - c2[1])^2 + (c1[2] - c2[2])^2)

    ntotal = sum(length, coordsset)
    stride = ntotal + length(hubs)

    for z in zrange
        for c in vcat(coordsset..., hubs)
            v(c[1], c[2], z)
        end
    end

    # bottom faces
    ofs = 0
    for coords in coordsset
        nc = length(coords)
        j1 = argmin(map(c -> dist(c, coords[1]), hubs)) + ntotal
        prevj = j1
        for i in 1:nc
            k = i + ofs
            l = mod1(i + 1, nc) + ofs
            j = argmin(map(c -> dist(c, coords[i]), hubs)) + ntotal
            if j != prevj
                f(prevj, k, j)
                prevj = j
            end
            f(j, k, l)
        end
        if prevj != j1
            f(prevj, 1 + ofs, j1)
        end
        ofs += nc
    end

    nf = length(faces)

    # top faces
    for i in 1:nf
        bf = indices(faces[i])
        f(bf[1] + stride, bf[3] + stride, bf[2] + stride)
    end

    # side faces
    ofs = 0
    for coords in coordsset
        nc = length(coords)
        for i in 1:nc
            inds = (i, i + stride, mod1(i + 1, nc) + stride, mod1(i + 1, nc))
            f((inds .+ ofs)...)
        end
        ofs += nc
    end

    return SimpleMesh(vertices, faces)
end

function generate_capital_g()
    local d = 32
    flipy(vec::Vec2) = Vec2(vec[1], -vec[2])

    svg = read(assetspath("capital_g.svg"), String)
    desc = match(r"d=\"([^\"]+)\"", svg)[1]

    coords = get_coords_from_svgpath(desc, d)
    hubs = flipy.(Vec2[(3.3, 0.9), (3.3, 3.2), (-2.3, 4.4), (-3.8, -2.8), (2.3, -4.4)])
    return generate_extruded_mesh(coords, hubs, (0.0, 2.0))
end


base = generate_base()
logomeshes = generate_logo()

@static if false
    open(assetspath("base.obj"), "w") do f
        write_obj(f, base)
    end

    open(assetspath("logo.obj"), "w") do f
        write_obj(f, logomeshes)
    end
end

open(assetspath("julia.obj"), "w") do f
    write_obj(f, [base; logomeshes])
end

capital_g = generate_capital_g()
open(assetspath("capital_g.obj"), "w") do f
    write_obj(f, capital_g)
end