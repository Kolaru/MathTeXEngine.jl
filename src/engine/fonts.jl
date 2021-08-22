const FONTS = RelocatableFolders.@path joinpath(@__DIR__, "..", "..", "assets", "fonts")

function full_fontpath(fontname::AbstractString)
    isfile(fontname) && return fontname
    return joinpath(FONTS, fontname)
end

const _cached_fonts = Dict{String, FTFont}()

"""
    load_font(str)

Load a font. `str` must be either the full path to the font file, or a font in
the package font folder.

A font at a given location is cached for further use.
"""
function load_font(str)
    path = full_fontpath(str)
    get!(_cached_fonts, path) do
        FTFont(path)
    end
end

# Loading the font directly here lead to FreeTypeAbstraction to fail with error
# code 35, because handles to fonts are C pointer that cannot be fully
# serialized at compile time
const _default_fonts = Dict(
    :regular => joinpath("NewComputerModern", "NewCM10-Regular.otf"),
    :italic => joinpath("NewComputerModern", "NewCM10-Italic.otf"),
    :bold => joinpath("NewComputerModern", "NewCM10-Bold.otf"),
    :bolditalic => joinpath("NewComputerModern", "NewCM10-BoldItalic.otf"),
    :math => joinpath("NewComputerModern", "NewCMMath-Regular.otf")
)

const _default_font_mapping = Dict(
    :text => :regular,
    :delimiter => :regular,
    :digit => :regular,
    :function => :regular,
    :punctuation => :regular,
    :symbol => :math,
    :char => :italic
)

const _default_font_modifiers = Dict(
    :rm => Dict(:bolditalic => :bold, :italic => :regular),
    :it => Dict(:bold => :bolditalic, :regular => :italic),
    :bf => Dict(:italic => :bolditalic, :regular => :bold)
)

"""
    FontSet([fonts, font_mapping, font_modifiers, slant_angle])

A set of font for LaTeX rendering.

# Fields
  - `font_mapping` a dict mapping the different character types (`:digit`,
    `:function`, `:punctuation`, `:symbol`, `:variable`) to a font identifier.
    Default to `MathTeXEngine._default_font_mapping`
  - `fonts` a dict mapping font identifier to a font path. Default to
    `MathTeXEngine._default_fonts` which represents the NewComputerModern font.
  - `font_modifiers` a dict of dict, one entry per font command supported in the
    font set. Each entry is a dict that maps a font identifier to another.
    Default to `MathTeXEngine._default_font_modifiers`.
  - `slant_angle` the angle by which the italic fonts are slanted, in degree
"""
struct FontSet
    fonts::Dict{Symbol, String}
    font_mapping::Dict{Symbol, Symbol}
    font_modifiers::Dict{Symbol, Dict{Symbol, Symbol}}
    slant_angle::Float64
end

FontSet(fonts) = FontSet(fonts, _default_font_mapping, _default_font_modifiers, 15)
FontSet() = FontSet(_default_fonts)

"""
    get_font([fontset=FontSet()], fontstyle)

Get the FTFont object representing a font in the given font family. When called
with a single argument uses the default font family.
"""
get_font(fontset::FontSet, fontstyle::Symbol) = load_font(fontset.fonts[fontstyle])
get_font(fontstyle::Symbol) = get_font(FontSet(), fontstyle)

"""
    get_fontpath([fontset::FontSet], fontstyle)

Similar to `get_font` but return the path of the font instead of the FTFont
object.
"""
get_fontpath(fontset::FontSet, fontstyle::Symbol) = full_fontpath(fontset.fonts[fontstyle])
get_fontpath(fontstyle::Symbol) = get_fontpath(FontSet(), fontstyle)

function is_slanted(fontset, char_type)
    font_id = fontset.font_mapping[char_type]
    return font_id == :italic
end

slant_angle(fontset) = fontset.slant_angle * π / 180

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
thickness(fontset::FontSet) = thickness(get_font(fontset, :math))

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
xheight(fontset) = xheight(get_font(fontset, :regular))


