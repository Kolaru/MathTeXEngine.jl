using MathTeXEngine
using CairoMakie
using Colors
using GeometryBasics
using LaTeXStrings

import MathTeXEngine: TeXChar, VLine, HLine, leftinkbound, descender, inkwidth,
    topinkbound, advance, bottominkbound, rightinkbound, ascender

draw_texelement!(args... ; size=64) = nothing

function draw_texelement!(ax, texchar::TeXChar, position, scale ; size=64)
    x = (position[1] + leftinkbound(texchar)) * size
    y = (position[2] + descender(texchar.font) * scale) * size
    text!(ax, string(texchar.char), font=texchar.font,
        position=Point2f(x, y),
        textsize=size*scale,
        space=:data)
end

function draw_texelement!(ax, line::VLine, position, scale ; size=64)
    lw = line.thickness * scale / 2
    xmid, y0 = position
    x0 = xmid - lw
    x1 = xmid + lw
    y1 = y0 + line.height * scale
    points = Point2f[(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
    poly!(ax, points .* size, color=:black, shading=false, linewidth=0)
end

function draw_texelement!(ax, line::HLine, position, scale ; size=64)
    lw = line.thickness * scale / 2
    x0, ymid = position
    x1 = x0 + line.width * scale
    y0 = ymid - lw
    y1 = ymid + lw
    points = Point2f[(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
    mesh!(ax, points .* size, color=:black, shading=false)
end

draw_texelement_helpers!(args... ; size=64) = nothing

# TODO Move helper rect to the module
function draw_texelement_helpers!(ax, texchar::TeXChar, position, scale ; size=64)
    x = position[1] * size
    # Characters are drawn from the bottom left of the font bounding box but
    # their position is relative to the baseline, so we need to offset them
    y = position[2] * size
    w = inkwidth(texchar) * size * scale
    a = advance(texchar) * size * scale
    top = topinkbound(texchar) * size * scale
    bottom = bottominkbound(texchar) * size * scale
    left = leftinkbound(texchar) * size * scale
    right = rightinkbound(texchar) * size * scale

    asc = ascender(texchar) * size * scale
    desc = descender(texchar) * size * scale

    # The space between th origin and the left ink bound
    mesh!(ax,
        Point2f[
            (x, y + bottom),
            (x + left, y + bottom),
            (x + left, y + top),
            (x, y + top)
        ],
        color=RGBA(1, 1, 0, 0.6),
        shading=false
    )

    # The advance after the right inkbound
    mesh!(ax,
        Point2f[
            (x + right, y + bottom),
            (x + a, y + bottom),
            (x + a, y + top),
            (x + right, y + top)
        ],
        color=RGBA(0, 1, 0, 0.3),
        shading=false
    )

    # The descender
    mesh!(ax,
        Point2f[
            (x + left, y),
            (x + right, y),
            (x + right, y + bottom),
            (x + left, y + bottom)
        ],
        color=RGBA(0, 0, 1, 0.3),
        shading=false
    )

    # The inkbound above the baseline
    mesh!(ax,
        Point2f[
            (x + left, y),
            (x + right, y),
            (x + right, y + top),
            (x + left, y + top)
        ],
        color=RGBA(1, 0, 0, 0.5),
        shading=false
    )

    # Descender
    lines!(ax,
        [x + left, x + a],
        [y + desc, y + desc],
        color=:green
    )

    # Ascender
    lines!(ax,
        [x + left, x + a],
        [y + asc, y + asc],
        color=:blue
    )
end

function makie_tex!(
        ax, latex::LaTeXString ;
        debug=false,
        size=64,
        position=[0, 0])

    for (elem, pos, scale) in generate_tex_elements(latex)
        draw_texelement!(ax, elem, pos .+ position, scale ; size=size)
        if debug
            draw_texelement_helpers!(ax, elem, pos .+ position, scale ; size=size)
        end
    end
end

begin  # Quick test
    fig = Figure(resolution=(1800, 600))
    fig[1, 1] = Label(fig, "LaTeX in Makie.jl", tellwidth=false, textsize=64)
    ax = Axis(fig[2, 1])
    ax.aspect = DataAspect()
    tex = L"\lim_{L →\infty} \gamma A^\sqrt{2 + 3 + 2} z^2 = \sum_{k = 1}^N \vec{v}_{(a + \bar{a})_k} + \sqrt{j} x! \quad \mathrm{when} \quad \sqrt{\frac{\Omega-2}{4+a+x}} < \int_{0}^{2π} |\sin(\mu x)| dx"

    makie_tex!(ax, tex, debug=true, size=300)
    makie_tex!(ax, L"\sum x_k y_k", debug=true, size=300, position=(0, -5))
    fig
end
