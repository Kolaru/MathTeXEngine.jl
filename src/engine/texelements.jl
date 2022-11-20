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
    hadvance(elem::TeXElement)

Return the horizontal distance between the origin of the element and the origin of the
next element to be drawn, without kerning.
"""
hadvance(x::TeXElement) = inkwidth(x)

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
    is_slanted(x::TeXElement)

Return whether the given element is slanted.
"""
is_slanted(x::TeXElement) = false

slant_angle(x::TeXElement) = 0.0
leftmost_glyph(x::TeXElement) = x
rightmost_glyph(x::TeXElement) = x

"""
    TeXChar(char, font)

A MathTeX character with an associated font.

TeXChar implement all functions defined for FreeTypeAbstraction.FontExtents
and can be used instead to get all geometric information about the
character.

This is especially useful since for fonts that require some adjustement for the
proper positioning of math symbols.

Fields
======
    - glyph_id::Culong The ID of the glyph representing the char in
        the associated font.
    - font::FTFont The font that should be used to display this character.
    - font_family::FontFamily The font family of the character.
    - slanted::Bool Whether this char is considered italic.
    - represented_char::Char The char represented by this char.
        Different from char for in some cases.
"""
struct TeXChar <: TeXElement
    glyph_id::Culong
    font::FTFont
    font_family::FontFamily
    slanted::Bool
    represented_char::Char
end

function TeXChar(char::Char, state::LayoutState, char_type)
    font_family = state.font_family

    if haskey(font_family.special_chars, char)
        fontpath, id = font_family.special_chars[char]
        font = load_font(fontpath)
        return TeXChar(id, font, font_family, false, char)
    end

    font = get_font(state, char_type)

    return TeXChar(
        glyph_index(font, char),
        font,
        font_family,
        is_slanted(state.font_family, char_type),
        char)
end

function TeXChar(name::AbstractString, state::LayoutState, char_type ; represented='?')
    font_family = state.font_family
    font = get_font(state, char_type)
    return TeXChar(
        glyph_index(font, name),
        font,
        font_family,
        is_slanted(state.font_family, char_type),
        represented)
end

for inkfunc in (:leftinkbound, :rightinkbound, :bottominkbound, :topinkbound)
    @eval $inkfunc(char::TeXChar) = $inkfunc(get_extent(char.font, char.glyph_id))
end

glyph_index(char::TeXChar) = char.glyph_id
hadvance(char::TeXChar) = hadvance(get_extent(char.font, char.glyph_id))
xheight(char::TeXChar) = xheight(char.font_family)

function ascender(char::TeXChar)
    math_font = get_font(char.font_family, :math)
    return max(ascender(math_font), topinkbound(char))
end

function descender(char::TeXChar)
    math_font = get_font(char.font_family, :regular)
    return min(descender(math_font), bottominkbound(char))
end

function FreeTypeAbstraction.height_insensitive_boundingbox(char::TeXChar, font)
    return Rect2f(
        leftinkbound(char), descender(char),
        inkwidth(char), ascender(char) - descender(char)
    )
end

is_slanted(char::TeXChar) = char.slanted
slant_angle(char::TeXChar) = slant_angle(char.font_family)

Base.show(io::IO, tc::TeXChar) =
    print(io, "TeXChar '$(tc.represented_char)' [index $(tc.glyph_id) in $(tc.font.family_name) - $(tc.font.style_name)]")


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

function hadvance(g::Group)
    adv = xpositions(g) .+ hadvance.(g.elements) .* g.scales
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

leftmost_glyph(g::Group) = leftmost_glyph(first(g.elements))
rightmost_glyph(g::Group) = rightmost_glyph(last(glyph))