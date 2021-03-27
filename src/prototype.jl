using FreeTypeAbstraction
import GeometryBasics: Point2f0
using MathTeXParser

import FreeTypeAbstraction:
    ascender, descender, get_extent, hadvance, inkheight, inkwidth,
    leftinkbound, rightinkbound, topinkbound, bottominkbound

include("fonts.jl")

struct TeXChar
    char::Char
    font::FTFont
end

TeXChar(char, path::AbstractString, command) = TeXChar(char, FTFont(path), command)

Base.show(io::IO, tc::TeXChar) =
    print(io, "TeXChar '$(tc.char)' [U+$(uppercase(string(codepoint(tc.char), base=16, pad=4))) in $(tc.font.family_name) - $(tc.font.style_name)]")

advance(char::TeXChar) = hadvance(get_extent(char.font, char.char))
ascender(char::TeXChar) = ascender(char.font)
descender(char::TeXChar) = descender(char.font)
xheight(char::TeXChar) = xheight(char.font)
    
struct Space
    width
end

advance(s::Space) = s.width
ascender(::Space) = 0
descender(::Space) = 0
xheight(::Space) = 0

struct ScaledChar
    char::TeXChar
    scale
end

for func in (:advance, :ascender, :descender, :xheight)
    @eval $func(scaled::ScaledChar) = $func(scaled.char) * scaled.scale
end

for inkfunc in (:leftinkbound, :rightinkbound, :bottominkbound, :topinkbound)
    @eval $inkfunc(::Space) = 0
    @eval $inkfunc(char::TeXChar) = $inkfunc(get_extent(char.font, char.char))
    @eval $inkfunc(scaled::ScaledChar) = $inkfunc(scaled.char) * scaled.scale
end

struct Line
    v
    thickness
end

advance(line::Line) = inkwidth(line)
ascender(::Line) = 0
descender(::Line) = 0
xheight(::Line) = 0
leftinkbound(line::Line) = min(line.v[1], 0)
rightinkbound(line::Line) = max(line.v[1], 0)
bottominkbound(line::Line) = min(line.v[2], 0)
topinkbound(line::Line) = max(line.v[2], 0)


hmid(x) = 0.5*(leftinkbound(x) + rightinkbound(x))
vmid(x) = 0.5*(bottominkbound(x) + topinkbound(x))
inkwidth(x) = rightinkbound(x) - leftinkbound(x)
inkheight(x) = topinkbound(x) - bottominkbound(x)

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
    return minimum(des)
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

# y position to get under some element
under_offset(elem, under, scale=1) = bottominkbound(elem) - (ascender(under) - xheight(under)/2) * scale
# y position to get over some element
over_offset(elem, over) = topinkbound(elem) - descender(over)

tex_layout(char::TeXChar, fontset) = char
tex_layout(::Nothing, fontset) = Space(0)
tex_layout(char::Char, fontset) = get_math_char(char, fontset)

function tex_layout(integer::Integer, fontset)
    elements = get_number_char.(collect(string(integer)), Ref(fontset))
    return horizontal_layout(elements)
end

function tex_layout(expr, fontset=NewComputerModern)
    head = expr.head
    args = [expr.args...]
    n = length(args)
    shrink = 0.6

    if head == :group
        elements = tex_layout.(args, Ref(fontset))
        return horizontal_layout(elements)
    elseif head == :decorated
        core, sub, super = tex_layout.(args, Ref(fontset))

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
        sub, super = tex_layout.(args[2:3], Ref(fontset))

        # TODO: Use proper LaTeX Integral Symbol
        # This one is too heavy / thick
        intchar = get_symbol_char('∫', raw"\int", fontset)
        int = ScaledChar(intchar, 2)

        iw = advance(int)
        xh = xheight(fontset.math)
        ih = inkheight(int)

        # last term corrects asymmetry of integral char
        y0 = xh/2 - ih/2 - bottominkbound(int) 
        subpos =  Point2f0(iw/2, -ih/2)
        superpos =  Point2f0(iw, ih/2)

        return Group(
            [int, sub, super],
            [Point2f0(0, y0), subpos, superpos],
            [1, shrink, shrink]
            )
    elseif head == :underover
        core, sub, super = tex_layout.(args, Ref(fontset))

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
                    under_offset(core, sub, shrink)),
                Point2f0(
                    x0 + dxsuper,
                    over_offset(core, super))
            ],
            [1, shrink, shrink]
        )
    elseif head == :function
        name = args[1]
        elements = get_function_char.(collect(name), Ref(fontset))
        return horizontal_layout(elements)
    elseif head == :space
        return Space(args[1])
    elseif head == :spaced_symbol
        char, command = args[1].args
        sym = get_symbol_char(char, command, fontset)
        return horizontal_layout([Space(0.2), sym, Space(0.2)])
    elseif head == :delimited
        # TODO Parsing of this is crippling slow and I don't know why
        elements = tex_layout.(args, Ref(fontset))
        left, content, right = elements

        height = inkheight(content)
        left_scale = max(1, height / inkheight(left))
        right_scale = max(1, height / inkheight(right))
        scales = [left_scale, 1, right_scale]
            
        dxs = advance.(elements) .* scales
        xs = [0, cumsum(dxs[1:end-1])...]

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
        numerator = tex_layout(args[1], fontset)
        denominator = tex_layout(args[2], fontset)

        # extend fraction line by half an xheight
        xh = xheight(fontset.math)
        w = max(inkwidth(numerator), inkwidth(denominator)) + xh/2

        # fixed width fraction line
        lw = thickness(fontset)

        line = Line(Point2f0(w,0), lw)
        y0 = xh/2 - lw/2

        # horizontal center align for numerator and denominator
        x1 = (w-inkwidth(numerator))/2
        x2 = (w-inkwidth(denominator))/2

        ytop    = y0 + xh/2 - bottominkbound(numerator)
        ybottom = y0 - xh/2 - topinkbound(denominator)

        return Group(
            [line, numerator, denominator],
            [Point2f0(0,y0), Point2f0(x1, ytop), Point2f0(x2, ybottom)],
            [1,1,1]
            )
    elseif head == :sqrt
        content = tex_layout(args[1], fontset)
        sq = get_symbol_char('√', raw"\sqrt", fontset)

        thick = thickness(fontset)
        relpad = 0.15

        h = inkheight(content)
        pad = relpad * h
        h += 2pad
    
        scale = h / inkheight(sq)
        lw = thickness(fontset) * scale

        sqrt = ScaledChar(sq, scale)

        # The root symbol must be manually placed
        y0 = bottominkbound(content) - bottominkbound(sqrt) - pad/2
        x = inkwidth(sqrt) - lw/2
        y = y0 + topinkbound(sqrt) - lw/2
        w =  inkwidth(content) + 0.2
        line = Line(Point2f0(w, 0), lw)

        return Group(
            [sq, line, content],
            [Point2f0(0, y0), Point2f0(x, y), Point2f0(x, 0)],
            [scale, 1, 1])
    elseif head == :symbol
        char, command = args
        return get_symbol_char(char, command, fontset)
    end

    @error "Unsupported expr $expr"
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

function draw_glyph!(ax, texchar::TeXChar, position, scale)
    size = 64
    x = position[1] * size
    # Characters are drawn from the bottom left of the font bounding box but
    # their position is relative to the baseline, so we need to offset them
    y = (position[2] + descender(texchar.font) * scale) * size
    text!(ax, string(texchar.char), font=texchar.font,
        position=Point2f0(x, y),
        textsize=size*scale,
        space=:data)
end

draw_glyph!(ax, space::Space, position, scale) = nothing
draw_glyph!(ax, scaled::ScaledChar, position, scale) = draw_glyph!(ax, scaled.char, position, scale * scaled.scale)

function draw_glyph!(ax, line::Line, position, scale)
    x0, y0 = position
    xs = [x0, x0 + line.v[1]]
    ys = [y0, y0 + line.v[2]]
    lines!(ax, xs .* 64, ys .* 64, linewidth=line.thickness * scale * 64)
end

##
begin  # Quick test
    using CairoMakie
    
    fig = Figure()
    fig[1, 1] = Label(fig, "LaTeX in Makie.jl", tellwidth=false, textsize=64)
    ax = Axis(fig[2, 1])
    ax.aspect = DataAspect()
    hidedecorations!(ax)
    #tex = raw"\sqrt{\cos(\omega t)} = \lim_{x →\infty} A^j v_{(a + b)_k}^i \sqrt{2} \sqrt{\Lambda_L \sum^j_m} \sum_{k=1234}^n 22k  \nabla x!=\frac{1+2}{4+a+g}\int"
    tex = raw"\lim_{x →\infty} A^j v_{(a + b)_k}^i \sqrt{2} \nabla x!=\frac{1+2}{4+a+g}\int_{0}^{2π} \sin(x)\, dx"
    expr = parse(TeXExpr, tex)
    layout = tex_layout(expr)

    for (elem, pos, scale) in unravel(layout)
        draw_glyph!(ax, elem, pos, scale)
    end
    fig
end
##
save("test.pdf", fig)

