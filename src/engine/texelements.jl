"""
    TeXElement

Abstract super type for elements of a MathTeX string.

Currently represent either
    - a char
    - a space
    - a horizontal or vertical line
    - a group of TeXElements positioned relative to each other
"""
abstract type TeXElement end

"""
    leftinkbound(elem::TeXElement)

Return the position of the leftmost position the ink of the element uses.
"""
function leftinkbound end

"""
    rightinkbound(elem::TeXElement)

Return the position of the rightmost position the ink of the element uses.
"""
function rightinkbound end

"""
    bottominkbound(elem::TeXElement)

Return the position of the lowest position the ink of the element uses.
"""
function bottominkbound end

"""
    topinkbound(elem::TeXElement)

Return the position of the highest position the ink of the element uses.
"""
function topinkbound end

"""
    advance(elem::TeXElement)

Return the horizontal distance between the origin of the element and the origin of the
next element to be drawn, without kerning.
"""
advance(x::TeXElement) = inkwidth(x)

"""
    ascender(elem::TeXElement)

Return the vertical spaced reserved above the element, measured from the
baseline.

Only makes sense for TeXChar and derived elements, is set to zero for all other
for convenience.
"""
ascender(x::TeXElement) = 0

"""
    descender(elem::TeXElement)

Return the vertical spaced reserved below the element, measured from the
baseline.

Only makes sense for TeXChar and derived elements, is set to zero for all other
for convenience.
"""
descender(x::TeXElement) = 0

"""
    xheight(elem::TeXElement)

Return the height of the 'x' character associated to the font of the element.

Only makes sense for TeXChar and derived elements, is set to zero for all other
for convenience.
"""
xheight(x::TeXElement) = 0

"""
    hmid(elem::TeXElement)

Return the horizontal middle of the element ink.
"""
hmid(x::TeXElement) = 0.5*(leftinkbound(x) + rightinkbound(x))

"""
    vmid(elem::TeXElement)

Return the vertical middle of the element ink.
"""
vmid(x::TeXElement) = 0.5*(bottominkbound(x) + topinkbound(x))

"""
    inkwidth(elem::TeXElement)

Return the total width of the element ink.
"""
inkwidth(x::TeXElement) = rightinkbound(x) - leftinkbound(x)

"""
    inkheight(elem::TeXElement)

Return the total height of the element ink.
"""
inkheight(x::TeXElement) = topinkbound(x) - bottominkbound(x)

"""
    TeXChar(char, font)

A MathTeX character with an associated font.

Fields
======
    - char::Char The code point of the glyph representing the char.
    - font::FTFont The font that should be used to display this character.
    - slanted::Bool Whether this char is considered italic.
    - represented_char::Char The char represented by this char.
        Different from char for non-unicode fonts.
"""
struct TeXChar <: TeXElement
    char::Char
    font::FTFont
    slanted::Bool
    represented_char::Char
end

function TeXChar(char, state::LayoutState, char_type)
    font_family = state.font_family

    if haskey(font_family.special_chars, char)
        fontpath, id = font_family.special_chars[char]
        font = load_font(fontpath)
        return TeXChar(id, font, false, char)
    end

    return TeXChar(
        char,
        get_font(state, char_type),
        is_slanted(state.font_family, char_type),
        char)
end

TeXChar(char::Char, font::FTFont) = TeXChar(char, font, false, char)

for inkfunc in (:leftinkbound, :rightinkbound, :bottominkbound, :topinkbound)
    @eval $inkfunc(char::TeXChar) = $inkfunc(get_extent(char.font, char.char))
end

advance(char::TeXChar) = hadvance(get_extent(char.font, char.char))
xheight(char::TeXChar) = xheight(char.font)

function ascender(char::TeXChar)
    # Special cases for symbol fonts
    if char.font.family_name == "cmsy10"
        regular_font = load_font(_default_fonts[:regular])
        return max(topinkbound(char), ascender(regular_font))
    end

    if char.font.family_name == "cmex10"
        return topinkbound(char)
    end

    return ascender(char.font)
end

function descender(char::TeXChar)
    # Special cases for symbol fonts
    if char.font.family_name == "cmsy10"
        regular_font = load_font(_default_fonts[:regular])
        return min(bottominkbound(char), descender(regular_font))
    end

    if char.font.family_name == "cmex10"
        return bottominkbound(char)
    end

    return descender(char.font)
end

Base.show(io::IO, tc::TeXChar) =
    print(io, "TeXChar '$(tc.represented_char)' [U+$(uppercase(string(codepoint(tc.char), base=16, pad=4))) in $(tc.font.family_name) - $(tc.font.style_name)]")


"""
    Space

A MathTeX space of a given width.

Fields
======
    - width::Real The width of the space.
"""
struct Space{T} <: TeXElement
    width::T
end

leftinkbound(::Space) = 0
rightinkbound(s::Space) = s.width
bottominkbound(::Space) = 0
topinkbound(::Space) = 0

"""
    Vline

A vertical line.

Fields
======
    - height::Real The span of the line in the vertical direction.
    - thickness::Real The thickness of the line.
"""
struct VLine{T} <: TeXElement
    height::T
    thickness::T
end

VLine(height, thickness) = VLine(promote(height, thickness)...)

leftinkbound(line::VLine) = -line.thickness/2
rightinkbound(line::VLine) = line.thickness/2
bottominkbound(line::VLine{T}) where T = min(line.height, zero(T))
topinkbound(line::VLine{T}) where T = max(line.height, zero(T))

"""
    Hline

A horizontal line.

Fields
======
    - width::Real The span of the line in the horizontal direction.
    - thickness::Real The thickness of the line.
"""
struct HLine{T} <: TeXElement
    width::T
    thickness::T
end

HLine(height, thickness) = HLine(promote(height, thickness)...)

leftinkbound(line::HLine{T}) where T = min(line.width, zero(T))
rightinkbound(line::HLine{T}) where T = max(line.width, zero(T))
bottominkbound(line::HLine) = -line.thickness/2
topinkbound(line::HLine) = line.thickness/2

"""
    Group

A group of TeXElements.

Positions and scales are relative to the group.

Fields
======
    - elements::Vector{<:TeXElement} Vector of the elements contained in the group.
    - positions::Vector{Point2f} Vector of the relative positions of the contained elements.
    - scales::Vector Vector of the relative scales of the contained elements.
"""
struct Group{T} <: TeXElement
    elements::Vector{<:TeXElement}
    positions::Vector{Point2f}
    scales::Vector{T}
end

Group(elements, positions) = Group(elements, positions, ones(length(elements)))

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

xheight(g::Group) = maximum(xheight.(g.elements) .* g.scales)
