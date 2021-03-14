using FreeTypeAbstraction
using GeometryBasics
using MathTeXParser

import FreeTypeAbstraction:
    ascender, descender, get_extent, hadvance, inkheight, inkwidth,
    leftinkbound, rightinkbound, topinkbound, bottominkbound

include("symbols.jl")

"""

The height of the letter x in the given font, i.e. the height of the letters
without neither ascender nor descender.
"""
xheight(font::FTFont) = inkheight(TeXChar('x', font))


# Positions (resp. scales) are positions of the elements relative to the parent
# Absolute pos and scales will get computed when all gets flattened
struct Group
    elements::Vector
    positions::Vector{Point2f0}
    scales::Vector
end

function advance(g::Group)
    adv = xpositions(g) .+ advance.(g.elements) .* g.scales
    return maximum(adv)
end

function ascender(g::Group)
    asc = ypositions(g) .+ ascender.(g.elements) .* g.scales
    return maximum(asc)
end

function descender(g::Group)
    des = ypositions(g) .+ descender.(g.elements) .* g.scales
    return maximum(des)
end

xpositions(g::Group) = [p[1] for p in g.positions]
ypositions(g::Group) = [p[2] for p in g.positions]

function leftinkbound(g::Group)
    lefts = leftinkbound.(g.elements) .* g.scales .+ xpositions(g)
    return minimum(lefts)
end

function rightinkbound(g::Group)
    rights = rightinkbound.(g.elements) .* g.scales .+ xpositions(g)
    return maximum(rights)
end

function bottominkbound(g::Group)
    bottoms = bottominkbound.(g.elements) .* g.scales .+ ypositions(g)
    return minimum(bottoms)
end

function topinkbound(g::Group)
    tops = topinkbound.(g.elements) .* g.scales .+ ypositions(g)
    return maximum(tops)
end

xheight(g::Group) = maximum(xheight.(g.elements) .* g.scales)

struct Space
    width
end

advance(s::Space) = s.width
ascender(::Space) = 0
descender(::Space) = 0
xheight(::Space) = 0

advance(char::TeXChar) = hadvance(get_extent(char.font, char.char))
ascender(char::TeXChar) = ascender(char.font)
descender(char::TeXChar) = descender(char.font)
xheight(char::TeXChar) = xheight(char.font)

for inkfunc in (:leftinkbound, :rightinkbound, :bottominkbound, :topinkbound)
    @eval $inkfunc(::Space) = 0
    @eval $inkfunc(char::TeXChar) = $inkfunc(get_extent(char.font, char.char))
end

hmid(x) = 0.5*(leftinkbound(x) + rightinkbound(x))
vmid(x) = 0.5*(bottominkbound(x) + topinkbound(x))
inkwidth(x) = rightinkbound(x) - leftinkbound(x)
inkheight(x) = topinkbound(x) - bottominkbound(x)

tex_layout(char::TeXChar) = char
tex_layout(::Nothing) = Space(0)

function tex_layout(integer::Integer, fontenv=DefaultFontEnv)
    elements = TeXChar.(collect(string(integer)), fontenv.number_font)
    return horizontal_layout(elements)
end

function tex_layout(char::Char, fontenv=DefaultFontEnv)
    # TODO Do this better and not hard coded
    # TODO better fontenv interface
    if char in raw".;:!?()[]"
        TeXChar(char, NewCMRegularFont)
    else
        TeXChar(char, fontenv.math_font)
    end
end

# I don't see a reason to go through the Box, HList, VList business
# Let's see if I'll regret it ;)
function tex_layout(expr, fontenv=DefaultFontEnv)
    head = expr.head
    args = [expr.args...]
    n = length(args)
    shrink = 0.6

    if head == :group
        elements = tex_layout.(args, Ref(DefaultFontEnv))
        return horizontal_layout(elements)
    elseif head == :decorated
        core, sub, super = tex_layout.(args)

        core_width = advance(core)
        sub_width = advance(sub) * shrink
        super_width = advance(super) * shrink


        return Group(
            [core, sub, super],
            [
                Point2f0(0, 0),
                Point2f0(core_width, -0.2),
                Point2f0(core_width, xheight(core) - 0.5 * descender(super))],
            [1, shrink, shrink])
    elseif head == :integral
        # TODO
    elseif head == :underover
        core, sub, super = tex_layout.(args)

        mid = hmid(core)
        dxsub = mid - hmid(sub) * shrink
        dxsuper = mid - hmid(super) * shrink

        # The leftmost element must have x = 0
        x0 = -min(0, dxsub, dxsuper)

        return Group(
            [core, sub, super],
            [
                Point2f0(x0, 0),
                Point2f0(
                    x0 + dxsub,
                    bottominkbound(core) - (ascender(sub) - xheight(sub)/2) * shrink),
                Point2f0(
                    x0 + dxsuper,
                    topinkbound(core) - descender(super))
            ],
            [1, shrink, shrink]
        )
    elseif head == :function
        name = args[1]
        elements = TeXChar.(collect(name), fontenv.function_font)
        return horizontal_layout(elements)
    elseif head == :space
        return Space(args[1])
    elseif head == :spaced_symbol # TODO add :symbol head to the symbol when needed
        sym = TeXChar(args[1].args[1], fontenv.function_font)
        return horizontal_layout([Space(0.2), sym, Space(0.2)])
    elseif head == :delimited
        grow = 1.1
        elements = tex_layout.(args)
        left, content, right = elements

        height = inkheight(content)
        left_scale = max(1, height / inkheight(left))
        right_scale = max(1, height / inkheight(right))
        scales = [left_scale, 1, right_scale]
            
        dxs = advance.(elements) .* scales
        xs = [0, cumsum(dxs[1:end-1])...]
        @show bottominkbound(content)
        # TODO Height calculation for the parenthesis looks wrong
        # TODO Check what the algorithm should be there
        # Center the delimiters in the middle of the bot and top baselines ?
        return Group(elements, [
            Point2f0(xs[1], -bottominkbound(left) + bottominkbound(content)),
            Point2f0(xs[2], 0),
            Point2f0(xs[3], -bottominkbound(right) + bottominkbound(content))
        ], scales)
    elseif head == :accent || head == :wide_accent
        # TODO
    elseif head == :font
        # TODO
    elseif head == :frac
        # TODO
    elseif head == :symbol
        return TeXChar(args[1], NewCMMathFont)
    end

    @error "Unsupported $expr"
end

function horizontal_layout(elements ; scales=ones(length(elements)))
    dxs = advance.(elements)
    xs = [0, cumsum(dxs[1:end-1])...]

    return Group(elements, Point2f0.(xs, 0), scales)
end

function unravel(group::Group, parent_pos=Point2f0(0), parent_scale=1.0f0)
    positions = [parent_pos .+ pos for pos in parent_scale .* group.positions]
    scales = group.scales .* parent_scale
    elements = []

    for (elem, pos, scale) in zip(group.elements, positions, scales)
        push!(elements, unravel(elem, pos, scale)...)
    end

    return elements
end

unravel(char, pos, scale) = [(char, pos, scale)]

draw_glyph!(args...) = nothing

function draw_glyph!(scene, texchar::TeXChar, position, scale)
    size = 64
    x = position[1] * size
    # Characters are drawn from the bottom left of the font bounding box but
    # their position is relative to the baseline, so we need to offset them
    y = (position[2] + descender(texchar.font)) * size
    text!(scene, string(texchar.char), font=texchar.font, position=Point2f0(x, y), textsize=size*scale)
end

draw_glyph!(scene, space::Space, position, scale) = nothing


begin  # Quick test
    using CairoMakie
    
    scene = Scene()
    tex = raw"∫ \cos(\omega t) = \lim_{x →\infty} A^j v_{(a + b)}^i \Lambda_L \sum^j_m \sum_{k=1234}^n 22k  \nabla x!"
    expr = parse(TeXExpr, tex)
    layout = tex_layout(expr)

    for (elem, pos, scale) in unravel(layout)
        draw_glyph!(scene, elem, pos, scale)
    end
    scene
end

save("supersub.pdf", scene)

