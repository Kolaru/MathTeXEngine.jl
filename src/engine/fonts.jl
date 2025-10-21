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
    :delimiter => :math,
    :digit => :math,
    :function => :math,
    :punctuation => :math,
    :symbol => :math,
    :char => :math
)

const _default_font_modifiers = Dict(
    :rm => Dict(:bolditalic => :bold, :italic => :regular),
    :it => Dict(:bold => :bolditalic, :regular => :italic),
    :bf => Dict(:italic => :bolditalic, :regular => :bold)
)

const _default_fonts = Dict(
    :regular => joinpath("NewComputerModern", "NewCMMath-Regular.otf"),
    :italic => joinpath("NewComputerModern", "NewCM10-Italic.otf"),
    :bold => joinpath("NewComputerModern", "NewCM10-Bold.otf"),
    :bolditalic => joinpath("NewComputerModern", "NewCM10-BoldItalic.otf"),
    :math => joinpath("NewComputerModern", "NewCMMath-Regular.otf")
)

const _default_mathfont_command_mapping = Dict(
    ## by default, `\mathbf` now acts like `\symbf`, i.e., its a glyph-substitution switch
    ## rather than a font switch. 
    ## To have it act like `\textbf`, add an entry `:bf` => (:text, :bf),
)

"""
    FontFamily(
        fonts; 
        font_mapping, font_modifiers, special_chars, slant_angle, thickness,
        unicode_math_substitutions, unicode_math_aliases, unicode_math_config,
        mathfont_command_mapping
    )

A set of font for LaTeX rendering.

# Required fields
  - `fonts` A with the path to 5 fonts (:regular, :italic, :bold, :bolditalic,
    and :math). The same font can be used for multiple entries, and unrelated
    fonts can be mixed.\n
    Missing fields are completed with the default fonts from NewComputerModern.\n
    It is suggested to use a proper `:math` font for best rendering results of 
    mathematical expressions.

# Optional fields
  - `font_mapping` a dict mapping the different character types (`:digit`,
    `:function`, `:punctuation`, `:symbol`, `:variable`) to a font identifier.\n
    This mapping is relevant mainly for characters typed in “math mode”, i.e., 
    characters enclosed by \\\$-signs, because otherwise the default text font is used.\n
    Defaults to `MathTeXEngine._default_font_mapping`.
  - `font_modifiers` a dict of dict, one entry per font command supported in the
    font set. Each entry is a dict that maps a font identifier to another.
    This dict determines the font selection of (nested) `\\textXX` commands.\n
    Defaults to `MathTeXEngine._default_font_modifiers`.
  - `special_chars` mapping for special characters that should not be
    represented by their default unicode glyph
    (for example necessary to access the big integral glyph).\n
    Defaults to an empty `Dict`.
  - `slant_angle` the angle by which the italic fonts are slanted, in degree.
  - `thickness` the thickness of the lines associated to the font.
  - `unicode_math_substitutions` is nested dict to determine glyph styling and 
    substitutions in math mode. See the README of the `UnicodeMath` sub-module for details.
    It is recommended to use `unicode_math_config` instead of setting this manually.\n
    Defaults to `MathTeXEngine.UCM.default_substitutions`.
  - `unicode_math_aliases` is a nested dict for style aliases by alphabet.
    It is recommended to use `unicode_math_config` instead of setting this manually.\n
    Defaults to `MathTeXEngine.UCM.default_aliases`.
  - `unicode_math_config` can be used to set `unicode_math_substitutions` and
    `unicode_math_aliases` in tandem by giving a valid `UCMConfig` object.\n
    For example, `UCMConfig(; math_style_spec=:iso)` will result in common glyphs adhering
    to ISO recommendations within mathematical expressions.\n
    Defaults to `nothing`.
  - `mathfont_command_mapping` is a `Dict{Symbol, Tuple{Symbol, Symbol}` and 
    configures the behavior of `\\mathXX` commands.
    By default `\\mathit` is synonymous for `\\symit` and rather than switching fonts, 
    for every glyph in the argument a fitting Unicode substitution is chosen.
    This corresponds to an entry `:it => (:sym, :it)`.
    To enable legacy behavior, add an entry `:it => (:text, it)`.\n
    Defaults to `MathTeXEngine._default_mathfont_command_mapping`.
"""
struct FontFamily
    fonts::Dict{Symbol, String}
    font_mapping::Dict{Symbol, Symbol}
    font_modifiers::Dict{Symbol, Dict{Symbol, Symbol}}
    special_chars::Dict{Char, Tuple{String, Int}}
    slant_angle::Float64
    thickness::Float64
    unicode_math_substitutions::Dict{Symbol, Dict{Symbol, Dict{Symbol, Symbol}}}
    unicode_math_aliases::Dict{Symbol, Dict{Symbol, Symbol}}
    mathfont_command_mapping::Dict{Symbol, Tuple{Symbol, Symbol}}
end

function FontFamily(fonts;
        font_mapping = _default_font_mapping,
        font_modifiers = _default_font_modifiers,
        special_chars = Dict{Char, Tuple{String, Int}}(),
        slant_angle = 13,
        thickness = 0.0375,
        unicode_math_substitutions = UCM.default_substitutions,
        unicode_math_aliases = UCM.default_aliases,
        unicode_math_config = nothing,
        mathfont_command_mapping = _default_mathfont_command_mapping
    )

    fonts = merge(_default_fonts, Dict(fonts))

    if isa(unicode_math_config, UCM.UCMConfig)
        unicode_math_substitutions, unicode_math_aliases = UCM.config_dicts(unicode_math_config)
    end
    
    return FontFamily(
        fonts,
        font_mapping,
        font_modifiers,
        special_chars,
        slant_angle,
        thickness,
        unicode_math_substitutions,
        unicode_math_aliases,
        mathfont_command_mapping
    )
end

"""
    FontFamily(name::String = "NewComputerModern")

One of the default set of font for LaTeX rendering.

Currently available are
- NewComputerModern
- TeXGyreHeros
- TeXGyrePagella
- LucioleMath

These names can also be used in a LaTeXString directly,
to set the font of a single string,
with the command `\\fontfamily`,
e.g. L"\\fontfamily{TeXGyreHeros}x^2_3".
"""
FontFamily() = get_texfont_family()
FontFamily(fontname::AbstractString) = default_font_families[fontname]

function Base.show(io::IO, family::FontFamily)
    println(io, "FontFamily with $(family.slant_angle)° slant angle and $(family.thickness) line thickness")
    for (key, font) in family.fonts
        spaces = " "^(12 - length(string(key)))
        println(io, "  $key$spaces=>  $font")
    end
end


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
    ),
    "TeXGyrePagella" => FontFamily(
        Dict(
            :regular => joinpath("TeXGyrePagellaMTE", "TeXGyrePagellaMTE-Regular.otf"),
            :italic => joinpath("TeXGyrePagellaMTE", "TeXGyrePagellaMTE-Italic.otf"),
            :bold => joinpath("TeXGyrePagellaMTE", "TeXGyrePagellaMTE-Bold.otf"),
            :bolditalic => joinpath("TeXGyrePagellaMTE", "TeXGyrePagellaMTE-BoldItalic.otf"),
            :math => joinpath("TeXGyrePagellaMTE", "TeXGyrePagellaMTE-Math.otf"),
        )
    ),
    "LucioleMath" => FontFamily(
        Dict(
            :regular => joinpath("Luciole-Math", "Luciole-Regular.ttf"),
            :italic => joinpath("Luciole-Math", "Luciole-Regular-Italic.ttf"),
            :bold => joinpath("Luciole-Math", "Luciole-Bold.ttf"),
            :bolditalic => joinpath("Luciole-Math", "Luciole-Bold-Italic.ttf"),
            :math => joinpath("Luciole-Math", "Luciole-Math.otf"),
        )
    )
)

const current_texfont_family = Ref(default_font_families["NewComputerModern"])

"""
    get_texfont_family()

Get the current default font family for the styling of LaTeXString.
"""
get_texfont_family() = current_texfont_family[]

"""
    set_texfont_family!([font_family::FontFamily])

Set a font family for the styling of LaTeXString.

See the documentaiton of `FontFamily` for more information.
"""
set_texfont_family!(font_family::FontFamily) = (current_texfont_family[] = font_family)

"""
    set_texfont_family!(; kwargs...)

Set a font family for the styling of LaTeXString,
using key-value to specify individual fonts.

For example, the following sets the regular font
(used for text and function names) to Utopia
(assuming that the Utopia font can be found at the given path).

```julia
set_texfont_family!(regular = "Utopia-Regular.ttf")
```

See the documentation of `FontFamily` for more information.
"""
function set_texfont_family!(; kwargs...)
    if length(kwargs) == 0
        return current_texfont_family[] = default_font_families["NewComputerModern"]
    end
    return set_texfont_family!(FontFamily(kwargs))
end

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

function is_slanted(font_family, char_type, char...)
    font_id = get(font_family.font_mapping, char_type, :math)
    return is_slanted(font_id, char...)
end
function is_slanted(font_id)
    return font_id == :italic || font_id == :bolditalic
end
function is_slanted(font_id, char)
    is_slanted(font_id) && return true

    if font_id == :math
        if haskey(UCM.chars_to_ucmchars, char)
            ucm_char = UCM.chars_to_ucmchars[char]
            if ucm_char.style in (:it, :bfit, :sfit, :bfsfit, :bbit)    # TODO `:bfcal` ?
                return true
            end
        end
    end
    return false
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
