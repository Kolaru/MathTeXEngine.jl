using FreeTypeAbstraction
import GeometryBasics: Point2f0
using MathTeXParser
using LaTeXStrings
import FreeTypeAbstraction:
    ascender, descender, get_extent, hadvance, inkheight, inkwidth,
    leftinkbound, rightinkbound, topinkbound, bottominkbound

include("fonts.jl")
include("texelements.jl")
include("layout.jl")

# Prototype for drawing
using CairoMakie
using Colors

draw_texelement!(args...) = nothing

function draw_texelement!(ax, texchar::TeXChar, position, scale ; size=64)
    x = position[1] * size
    # Characters are drawn from the bottom left of the font bounding box but
    # their position is relative to the baseline, so we need to offset them
    y = (position[2] + descender(texchar.font) * scale) * size
    text!(ax, string(texchar.char), font=texchar.font,
        position=Point2f0(x, y),
        textsize=size*scale,
        space=:data)
end

function draw_texelement!(ax, line::VLine, position, scale ; size=64)
    lw = line.thickness * scale / 2
    xmid, y0 = position
    x0 = xmid - lw
    x1 = xmid + lw
    y1 = y0 + line.height
    points = Point2f0[(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
    poly!(ax, points .* size, color=:black)
end

function draw_texelement!(ax, line::HLine, position, scale ; size=64)
    lw = line.thickness * scale / 2
    x0, ymid = position
    x1 = x0 + line.width
    y0 = ymid - lw
    y1 = ymid + lw
    points = Point2f0[(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
    poly!(ax, points .* size, color=:black)
end

draw_texelement_helpers!(args...) = nothing

function draw_texelement_helpers!(ax, texchar::TeXChar, position, scale)
    size = 64
    x = position[1] * size
    # Characters are drawn from the bottom left of the font bounding box but
    # their position is relative to the baseline, so we need to offset them
    y = position[2] * size
    w = inkwidth(texchar) * size * scale
    h = topinkbound(texchar) * size * scale
    a = advance(texchar) * size * scale
    d = bottominkbound(texchar) * size * scale
    left = leftinkbound(texchar) * size * scale

    # The space between th origin and the left ink bound
    poly!(ax, 
        Point2f0[
            (x, y + d),
            (x - left, y + d),
            (x - left, y + h),
            (x, y + h)
        ],
        color=RGBA(1, 1, 0, 0.6),
        strokecolor=RGBA(0, 0, 0, 0.0),
        strokewidth=1
    )

    # The advance after the right inkbound
    poly!(ax, 
        Point2f0[
            (x + w, y + d),
            (x + a, y + d),
            (x + a, y + h),
            (x + w, y + h)
        ],
        color=RGBA(0, 1, 0, 0.3),
        strokecolor=RGBA(0, 0, 0, 0.0),
        strokewidth=1
    )

    # The descender
    poly!(ax,
        Point2f0[
            (x, y),
            (x + w, y),
            (x + w, y + d),
            (x, y + d)
        ],
        color=RGBA(0, 0, 1, 0.3),
        strokecolor=RGBA(0, 0, 0, 0.0),
        strokewidth=1
    )

    # The inkbound above the baseline
    poly!(ax, 
        Point2f0[
            (x, y),
            (x + w, y),
            (x + w, y + h),
            (x, y + h)
        ],
        color=RGBA(1, 0, 0, 0.5),
        strokecolor=RGBA(0, 0, 0, 0.0),
        strokewidth=1
    )
end


function makie_tex!(ax, latex::LaTeXString ; debug=false)
    tex = latex[2:end-1]  # TODO Split string correctly at $. Do it in TeXParser ?
    expr = texparse(tex)
    layout = tex_layout(expr)

    for (elem, pos, scale) in unravel(layout)
        draw_texelement!(ax, elem, pos, scale)
        if debug
            draw_texelement_helpers!(ax, elem, pos, scale)
        end
    end
end

struct TeXLabel
    string::LaTeXString
end

function Makie.text!(ax, latex::TeXLabel ; kwargs...)
    makie_tex!(ax, latex.string)
    @show kwargs
end

Makie.MakieLayout.iswhitespace(late::TeXLabel) = false

begin  # Quick test
    fig = Figure()
    fig[1, 1] = Label(fig, "LaTeX in Makie.jl", tellwidth=false, textsize=64)
    ax = Axis(fig[2, 1])
    ax.aspect = DataAspect()

    tex = L"\lim_{x →\infty} A^j v_{(a + b)_k}^i \sqrt{2} x!= \sqrt{\frac{1+2}{4+a+g}}\int_{0}^{2π} \sin(x) dx"

    ax.xlabel = TeXLabel(L"\omega^2")
    fig
end
save("test.pdf", fig)
save("example.png", fig)

 