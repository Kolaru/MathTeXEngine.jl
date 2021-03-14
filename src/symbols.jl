using FreeTypeAbstraction

struct TeXChar
    char::Char
    font::FTFont
end

TeXChar(char, path::AbstractString, command) = TeXChar(char, FTFont(path), command)

Base.show(io::IO, tc::TeXChar) =
    print(io, "TeXChar '$(tc.char)' [U+$(uppercase(string(codepoint(tc.char), base=16, pad=4))) in $(tc.font.family_name) - $(tc.font.style_name)]")

boundingbox(tc::TeXChar) = FreeTypeAbstraction.boundingbox(tc.char, tc.font, 64)

struct SymbolSet
    name::String
    sym_to_char::Dict{String, TeXChar}
end

Base.getindex(set::SymbolSet, sym) = set.sym_to_char[sym]

struct FontEnv
    symbol_set::SymbolSet
    function_font::FTFont
    number_font::FTFont
    math_font::FTFont
end

include("symbol_sets/unicode.jl")

NewCMMathFont = FTFont("assets/fonts/NewCMMath-regular.otf")
NewCMSymbolSet = SymbolSet("NewCM Math",
    Dict([command => TeXChar(Char(code), NewCMMathFont)
          for (command, code) in _latex_to_unicode]))

NewCMRegularFont = FTFont("assets/fonts/NewCM10-regular.otf")
NewCMItalicFont = FTFont("assets/fonts/NewCM10-italic.otf")

DefaultFontEnv = FontEnv(
    NewCMSymbolSet,
    NewCMRegularFont,
    NewCMRegularFont,
    NewCMItalicFont
)