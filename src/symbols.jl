using FreeTypeAbstraction

struct TeXChar
    char::Char
    font::FTFont
end

TeXChar(char, path::AbstractString, command) = TeXChar(char, FTFont(path), command)

Base.show(io::IO, tc::TeXChar) =
    print(io, "TeXChar '$(tc.char)' [U+$(uppercase(string(codepoint(tc.char), base=16, pad=4))) in $(tc.font.family_name) - $(tc.font.style_name)]")

boundingbox(tc::TeXChar) = FreeTypeAbstraction.boundingbox(tc.char, tc.font, 64)

struct FontEnv
    function_font::FTFont
    number_font::FTFont
    math_font::FTFont
end

NewCMMathFont = FTFont("assets/fonts/NewCMMath-regular.otf")
NewCMRegularFont = FTFont("assets/fonts/NewCM10-regular.otf")
NewCMItalicFont = FTFont("assets/fonts/NewCM10-italic.otf")

DefaultFontEnv = FontEnv(
    NewCMRegularFont,
    NewCMRegularFont,
    NewCMItalicFont
)