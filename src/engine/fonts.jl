const FONTS = RelocatableFolders.@path joinpath(@__DIR__, "..", "..", "assets", "fonts")
fontpath(fontname) = joinpath(FONTS, fontname)

const _cached_fonts = Dict{String, FTFont}()

"""
    load_font(str)

Load a font. `str` must be either the full path to the font file, or a font in
the package font folder.

A font at a given location is cached for further use.
"""
function load_font(str)
    if isfile(str)
        path = str
    elseif isfile(fontpath(str))
        path = fontpath(str)
    end

    get!(_cached_fonts, path) do
        FTFont(path)
    end
end

# Loading the font directly here lead to FreeTypeAbstraction to fail with error code 35
const _default_fonts = Dict(
    :regular => joinpath("NewComputerModern", "NewCM10-Regular.otf"),
    :italic => joinpath("NewComputerModern", "NewCM10-Italic.otf"),
    :math => joinpath("NewComputerModern", "NewCMMath-Regular.otf")
)

const _default_font_mapping = Dict(
    :text => :regular,
    :digit => :regular,
    :function => :regular,
    :punctuation => :regular,
    :symbol => :math,
    :variable => :italic
)

"""
    Fontset([font_mapping, fonts])

A set of font for LaTeX rendering.

# Fields
  - `font_mapping` a dict mapping the different character types (`:digit`,
    `:function`, `:punctuation`, `:symbol`, `:variable`) to a font identifier.
    Default to `MathTeXEngine._default_font_mapping`
  - `fonts` a dict mapping font identifier to a font path. Default to
    `MathTeXEngine._default_fonts` which represents the NewComputerModern font.
"""
struct FontSet
    fonts::Dict{Symbol, String}
    font_mapping::Dict{Symbol, Symbol}
end

FontSet(fonts) = FontSet(fonts, _default_font_mapping)
FontSet() = FontSet(_default_fonts, _default_font_mapping)

function get_font(fontset, char_type)
    font_id = fontset.font_mapping[char_type]
    return fontset[font_id]
end

Base.getindex(fonset::FontSet, font_id) = load_font(fonset.fonts[font_id])

# Few helper functions
"""
    thickness(font::FTFont)

The thickness of the underline for the given font.
"""
thickness(font::FTFont) = font.underline_thickness / font.units_per_EM

"""
    thickness(font::FontSet)

The thickness of the underline for the given font set.
"""
thickness(fontset::FontSet) = thickness(fontset[:math])

"""
    xheight(font::FTFont)

The height of the letter x in the given font, i.e. the height of the letters
without neither ascender nor descender.
"""
xheight(font::FTFont) = inkheight(TeXChar('x', font))


"""
    xheight(font::FontSet)

The height of the letter x in the given fontset, i.e. the height of the letters
without neither ascender nor descender.
"""
xheight(fontset) = xheight(fontset[:regular])


