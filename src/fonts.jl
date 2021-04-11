using FreeTypeAbstraction

"""
    xheight(font::FTFont)

The height of the letter x in the given font, i.e. the height of the letters
without neither ascender nor descender.
"""
xheight(font::FTFont) = inkheight(TeXChar('x', font))
thickness(font::FTFont) = font.underline_thickness / font.units_per_EM

abstract type TeXFontSet end

struct NewCMFontSet <: TeXFontSet
    regular::FTFont
    italic::FTFont
    math::FTFont
end

function get_math_char(char::Char, fontset)
    if char in raw".;:!?()[]"
        TeXChar(char, fontset.regular)
    else
        TeXChar(char, fontset.italic)
    end
end

get_function_char(char::Char, fontset) = TeXChar(char, fontset.regular)
get_number_char(char::Char, fontset) = TeXChar(char, fontset.regular)

"""
    get_symbol_char(char, command, fontset)

Create a TeXChar for the character representing a symbol in the given
font set. The argument `command` contains the LaTeX command corresponding to the
character, to allow supporting non-unicode font sets.
"""
# TODO Substitute minus sign
get_symbol_char(char::Char, command, fontset) = TeXChar(char, fontset.math)

thickness(fontset) = thickness(fontset.math)
sqrt_thickness(fontset) = thickness(fontset.math)

xheight(fontset) = xheight(fontset.regular)

const NewComputerModern = NewCMFontSet(
    FTFont("assets/fonts/NewCM10-Regular.otf"),
    FTFont("assets/fonts/NewCM10-Italic.otf"),
    FTFont("assets/fonts/NewCMMath-Regular.otf")
)
