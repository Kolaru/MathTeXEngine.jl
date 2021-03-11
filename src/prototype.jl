using FreeTypeAbstraction
using GeometryBasics
using MathTeXParser

import FreeTypeAbstraction:
    ascender, descender, get_extent, hadvance, inkheight, inkwidth,
    leftinkbound, rightinkbound, topinkbound, bottominkbound

include("symbols.jl")

# Positions (resp. scales) are positions of the elements relative to the parent
# Absolute pos and scales will get computed when all gets flattened
struct Group
    elements::Vector
    positions::Vector{Point2f0}
    scales::Vector
    advance
end

advance(g::Group) = g.advance
descender(g::Group) = 0
xpositions(g::Group) = [p[1] for p in g.positions]
ypositions(g::Group) = [p[2] for p in g.positions]

function leftinkbound(group::Group)
    lefts = leftinkbound.(group.elements) .* group.scales .+ xpositions(group)
    return minimum(lefts)
end

function rightinkbound(group::Group)
    rights = rightinkbound.(group.elements) .* group.scales .+ xpositions(group)
    return maximum(rights)
end

function bottominkbound(group::Group)
    bottoms = bottominkbound.(group.elements) .* group.scales .+ ypositions(group)
    return minimum(bottoms)
end

function topinkbound(group::Group)
    tops = topinkbound.(group.elements) .* group.scales .+ ypositions(group)
    return maximum(tops)
end

struct Space
    advance
end

advance(s::Space) = s.advance
descender(::Space) = 0

advance(char::TeXChar) = hadvance(get_extent(char.font, char.char))
ascender(char::TeXChar) = ascender(char.font)
descender(char::TeXChar) = descender(char.font)

for inkfunc in (:leftinkbound, :rightinkbound, :bottominkbound, :topinkbound, :inkheight, :inkwidth)
    @eval $inkfunc(::Space) = 0
    @eval $inkfunc(char::TeXChar) = $inkfunc(get_extent(char.font, char.char))
end

hmid(x) = 0.5*(leftinkbound(x) + rightinkbound(x))
inkwidth(x) = rightinkbound(x) - leftinkbound(x)

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

        width = core_width + max(sub_width, super_width)

        y0 = descender(core)

        # TODO Make that not hacky as hell
        # Compute at which height to put superscript
        h = inkheight(TeXChar('u', NewCMItalicFont))

        ysub = y0 + descender(sub) * shrink

        return Group(
            [core, sub, super],
            [Point2f0(0, y0), Point2f0(core_width, ysub), Point2f0(core_width, h-0.2)],
            [1, shrink, shrink],
            width)
    elseif head == :integral
        # TODO
    elseif head == :underover
        pad = 0.2
        core, sub, super = tex_layout.(args)

        top = topinkbound(core)
        bot = bottominkbound(core)
        left = leftinkbound(core)
        right = rightinkbound(core)
        mid = hmid(core)

        y0 = descender(core)

        return Group(
            [core, sub, super],
            [
                Point2f0(0, y0),
                Point2f0(
                    mid - inkwidth(sub) * shrink / 2,
                    y0 + bot - pad - topinkbound(sub) * shrink),
                Point2f0(
                    mid - inkwidth(super) * shrink / 2,
                    y0 + top + pad)
            ],
            [1, shrink, shrink],
            advance(core)
        )
    elseif head == :function
        name = args[1]
        elements = TeXChar.(collect(name), fontenv.function_font)
        return horizontal_layout(elements)
    elseif head == :space
        return Space(args[1])
    elseif head == :spaced_symbol # TODO add :symbol head to the symbol when needed
        sym = TeXChar(args[1][1], fontenv.function_font)
        return horizontal_layout([Space(0.2), sym, Space(0.2)])
    elseif head == :delimited
        # TODO
    elseif head == :accent || head == :wide_accent
        # TODO
    elseif head == :font
        # TODO
    elseif head == :frac
        # TODO
    elseif head == :symbol
        return fontenv.symbol_set[args[1]]
    end

    @error "Something went wrong with $expr"
end

function horizontal_layout(elements)
    n = length(elements)
    dxs = zeros(n)
    ys = zeros(n)
    
    for (i, elem) in enumerate(elements)
        dxs[i] = advance(elem)
        ys[i] = descender(elem)
    end

    # We want the first to be 0 and to use the last as the advance of the group
    xs = zeros(n + 1)
    xs[2:end] = cumsum(dxs[1:end])

    scales = ones(n)
    return Group(elements, Point2f0.(xs[1:end-1], ys), scales, xs[end])
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


function draw_glyph!(scene, texchar, position, scale)
    size = 64
    text!(scene, string(texchar.char), font=texchar.font, position=position.*size, textsize=size*scale)
end

draw_glyph!(scene, space::Space, position, scale) = nothing


begin  # Quick test
    using CairoMakie
    
    scene = Scene()
    expr = parse(TeXExpr, raw"∫ \sin(\varphi) \cos(\omega t) = \lim_{x \infty} A^j v_{(a + b)}^i \Lambda_L \sum^j_m \sum_{k=1234}^n 22 \nabla x!")
    layout = tex_layout(expr)

    for (elem, pos, scale) in unravel(layout)
        draw_glyph!(scene, elem, pos, scale)
    end
    scene
end

save("supersub.pdf", scene)

