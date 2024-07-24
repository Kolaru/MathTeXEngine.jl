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
    FontFamily([fonts, font_mapping, font_modifiers, slant_angle])

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
struct FontFamily
    fonts::Dict{Symbol, String}
    font_mapping::Dict{Symbol, Symbol}
    font_modifiers::Dict{Symbol, Dict{Symbol, Symbol}}
    special_chars::Dict{Char, Tuple{String, Int}}
    slant_angle::Float64
    thickness::Float64
end

function FontFamily(fonts::Dict ;
        font_mapping = _default_font_mapping,
        font_modifiers = _default_font_modifiers,
        special_chars = Dict{Char, Tuple{String, Int}}(),
        slant_angle = 13,
        thickness = 0.0375)
    
    return FontFamily(
        fonts,
        font_mapping,
        font_modifiers,
        special_chars,
        slant_angle,
        thickness
    )
end

FontFamily() = FontFamily("NewComputerModern")
FontFamily(fontname::AbstractString) = default_font_families[fontname]

# These two fonts internals are very different, despite their similar names
# We only try to fully support NewComputerModern, the other is here as it may
# sometime provide quickfix solution to bug
const default_font_families = Dict(
    "NewComputerModern" => FontFamily(
        Dict(
            :regular => joinpath("NewComputerModern", "NewCMMath-Regular.otf"),
            :italic => joinpath("NewComputerModern", "NewCM10-Italic.otf"),
            :bold => joinpath("NewComputerModern", "NewCM10-Bold.otf"),
            :bolditalic => joinpath("NewComputerModern", "NewCM10-BoldItalic.otf"),
            :math => joinpath("NewComputerModern", "NewCMMath-Regular.otf")
        ),
        special_chars =_symbol_to_new_computer_modern),
    "TeXGyreHeros" => FontFamily(
        Dict(
            :regular => joinpath("TeXGyreHerosMakie", "TeXGyreHerosMakie-Regular.otf"),
            :italic => joinpath("TeXGyreHerosMakie", "TeXGyreHerosMakie-Italic.otf"),
            :bold => joinpath("TeXGyreHerosMakie", "TeXGyreHerosMakie-Bold.otf"),
            :bolditalic => joinpath("TeXGyreHerosMakie", "TeXGyreHerosMakie-BoldItalic.otf"),
            :math => joinpath("TeXGyreHerosMakie", "TeXGyreHerosMakie-Regular.otf")
        )
    )
)


"""
    get_font([font_family=FontFamily()], fontstyle)

Get the FTFont object representing a font in the given font family. When called
with a single argument uses the default font family.
"""
function get_font(font_family::FontFamily, fontstyle::Symbol)
    return load_font(font_family.fonts[fontstyle])
end
get_font(fontstyle::Symbol) = get_font(FontFamily(), fontstyle)

"""
    texfont(font_desc=:text)

Return the font used by MathTeXEngine.

If a font descriptor is given (e.g. :italic) return the font used for that
scenario.
"""
function texfont(font_desc=:text)
    family = FontFamily()
    
    haskey(family.fonts, font_desc) && return load_font(family.fonts[font_desc])
    haskey(family.font_mapping, font_desc) && return load_font(family.fonts[family.font_mapping[font_desc]])

    valids = vcat(collect(keys(family.fonts)), collect(keys(family.font_mapping)))
    valids = join([":$sym" for sym in valids], ", ", " and ")
    throw(ArgumentError(
        "Invalid font descriptor $font_desc, valid possibilites are $valids"
    ))
end

"""
    get_fontpath([font_family::FontFamily], fontstyle)

Similar to `get_font` but return the path of the font instead of the FTFont
object.
"""
get_fontpath(font_family::FontFamily, fontstyle::Symbol) = full_fontpath(font_family.fonts[fontstyle])
get_fontpath(fontstyle::Symbol) = get_fontpath(FontFamily(), fontstyle)

function is_slanted(font_family, char_type)
    font_id = font_family.font_mapping[char_type]
    return font_id == :italic
end

slant_angle(font_family) = font_family.slant_angle * π / 180

# Few helper functions
"""
    thickness(font::FontFamily)

The thickness of the underline for the given font set.
"""
thickness(font_family::FontFamily) = font_family.thickness

"""
    xheight(font::FontFamily)

The height of the letter x in the given font family, i.e. the height of the letters
without neither ascender nor descender.
"""
xheight(font_family) = inkheight(TeXChar('x', LayoutState(font_family), :text))
