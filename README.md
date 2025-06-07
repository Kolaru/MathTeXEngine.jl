# MathTeXEngine

This is a package aimed at providing a pure Julia engine for LaTeX math mode. It is composed of two main parts: a LaTeX parser and a LaTeX engine, both only for LaTeX math mode.

# Main features

- Parsing of (possibly nested) LaTeX expression and creation of a layout for them.
- Equivalence between traditional LaTeX commands and their unicode input equivalent.
- Pure julia.

# Fonts

The characters in a math expression come from a variety of fonts depending on their role (most notably italic for variable, regular for functions, math for the symbols).
A set of such font forms a `FontFamily`, and several are predefined here (NewComputerModer, TeXGyreHeros, TeXGyrePagella, and LucioleMath)
and can be access by `FontFamily(name)`.

A font family is defined by a dictionary of the paths of the font files:
```julia
julia> FontFamily("NewComputerModern")
FontFamily with 13.0° slant angle and 0.0375 line thickness
  bold        =>  NewComputerModern\NewCM10-Bold.otf
  bolditalic  =>  NewComputerModern\NewCM10-BoldItalic.otf
  italic      =>  NewComputerModern\NewCM10-Italic.otf
  math        =>  NewComputerModern\NewCMMath-Regular.otf
  regular     =>  NewComputerModern\NewCMMath-Regular.otf
```

Currently, there are two ways to get the font information to Makie.

First, change the global default font family using `set_texfont_family!`,
which take either a font family as an argument or a list of (`Symbol`, path to the font file) pairs.
```julia
# Change to a different font familiy entirely
julia> set_texfont_family!(FontFamily("LucioleMath"))
FontFamily with 13.0° slant angle and 0.0375 line thickness
  bold        =>  Luciole-Math\Luciole-Bold.ttf
  bolditalic  =>  Luciole-Math\Luciole-Bold-Italic.ttf
  italic      =>  Luciole-Math\Luciole-Regular-Italic.ttf
  math        =>  Luciole-Math\Luciole-Math.otf
  regular     =>  Luciole-Math\Luciole-Regular.ttf

# Change just the regular and bold fonts, keep the default for the rest
julia> set_texfont_family!(
   regular = raw"C:\Users\Kolaru\.julia\dev\MathTeXEngine\experimental\utopia\Utopia-Regular.ttf",
   bold = raw"C:\Users\Kolaru\.julia\dev\MathTeXEngine\experimental\utopia\Utopia-Bold.ttf")
FontFamily with 13.0° slant angle and 0.0375 line thickness
  bold        =>  C:\Users\Kolaru\.julia\dev\MathTeXEngine\experimental\utopia\Utopia-Bold.ttf
  bolditalic  =>  NewComputerModern\NewCM10-BoldItalic.otf
  italic      =>  NewComputerModern\NewCM10-Italic.otf
  math        =>  NewComputerModern\NewCMMath-Regular.otf
  regular     =>  C:\Users\Kolaru\.julia\dev\MathTeXEngine\experimental\utopia\Utopia-Regular.ttf

# Switch back to the default
julia> set_texfont_family!()
FontFamily with 13.0° slant angle and 0.0375 line thickness
  bold        =>  NewComputerModern\NewCM10-Bold.otf
  bolditalic  =>  NewComputerModern\NewCM10-BoldItalic.otf
  italic      =>  NewComputerModern\NewCM10-Italic.otf
  math        =>  NewComputerModern\NewCMMath-Regular.otf
  regular     =>  NewComputerModern\NewCMMath-Regular.otf
```

Alternatively, the special command `\fontfamily{FontName}` can be used in the LaTeX string itself
to choose the font, for example `L"\fontfamily{TeXGyreHeros}x^2 + y^2 = 1"`.
The font name must be in the global dictionary `MathTeXEngin.default_font_families`.
If needed, it can be extended at runtime.

# Engine

The main use of the package is through `generate_tex_elements` taking a LaTeX string as input and return a list of tuples `(TeXElement, position, scale)` where `TeXElement` is one of the following:

- `TeXChar(char, font)` a unicode character to be displayed in a specific font.
- `VLine(height, thickness)` a vertical line.
- `HLine(width, thickness)` an horizontal line.

This contains enough information to then draw everything with any plotting package that can draw arbitrary glyph in arbitrary font. The position is the origin of the character according to `FreeType`.

Positions and scales are given for a font size of `1`. For bigger font size they simply need to be multiplied by the font size.

The engine should support every construction the parser does (see below).

Currently the only font set supported is Computer Modern.

## Engine examples

### Basic examples

```julia
julia> using MathTeXEngine

julia> generate_tex_elements(L"\beta_2")
2-element Vector{Any}:
 (TeXChar 'β' [U+00AF in cmmi10 - Regular], [0.0, 0.0], 1.0)
 (TeXChar '2' [U+0032 in cmr10 - Regular], [0.56494140625, -0.20000000298023224], 0.6)
```

The `L"..."` macro is reexported from LaTeXStrings.jl and used to convey the information that we want the given string to be interpreted as LaTeX. Note that since we are using Computer Modern, which is a pre-unicode font family, the characters are distributed across a bunch of different fonts.

Also note that Unicode character can be used directly and are equivalent to their command.

```julia
julia> generate_tex_elements(L"β_2")
2-element Vector{Any}:
 (TeXChar 'β' [U+00AF in cmmi10 - Regular], [0.0, 0.0], 1.0)
 (TeXChar '2' [U+0032 in cmr10 - Regular], [0.56494140625, -0.20000000298023224], 0.6)
```

Using the inline math mode with `$...$` is supported. However, currently, line breaks or line wraps are not.

```julia
julia> generate_tex_elements(L"b $β_2$")
4-element Vector{Any}:
 (TeXChar 'b' [U+0062 in cmr10 - Regular], [0.0, 0.0], 1.0)
 (TeXChar ' ' [U+0020 in cmr10 - Regular], [0.55517578125, 0.0], 1.0)
 (TeXChar 'β' [U+00AF in cmmi10 - Regular], [0.88818359375, 0.0], 1.0)
 (TeXChar '2' [U+0032 in cmr10 - Regular], [1.453125, -0.20000000298023224], 0.6)
```

### VLine and Hline

Some LaTeX constructs, mainly square roots and fractions generate additional lines that are not representing a character. The `HLine` or `VLine` object contain all information needed to draw the line correctly.

```julia
julia> elements = generate_tex_elements(L"\frac{1}{2}")
3-element Vector{Any}:
 (HLine{Float64}(0.614990234375, 0.009765625), [0.0, 0.210693359375], 1.0)
 (TeXChar '1' [U+0031 in cmr10 - Regular], [0.1405029296875, 0.42626953125], 1.0)
 (TeXChar '2' [U+0032 in cmr10 - Regular], [0.1077880859375, -0.6708984375], 1.0)

julia> hline = elements[1][1]
HLine{Float64}(0.614990234375, 0.009765625)

julia> hline.width
0.614990234375

julia> hline.thickness
0.009765625
```

### Nested expressions

A flat list is always returned even if the LaTeX expression is deeply nested.

```julia
julia> generate_tex_elements(L"A_{B_{C_D}}")
4-element Vector{Any}:
 (TeXChar 'A' [U+0041 in cmmi10 - Regular], [0.0, 0.0], 1.0)
 (TeXChar 'B' [U+0042 in cmmi10 - Regular], [0.75, -0.20000000298023224], 0.6)
 (TeXChar 'C' [U+0043 in cmmi10 - Regular], [1.2046875, -0.3200000047683716], 0.36)
 (TeXChar 'D' [U+0044 in cmmi10 - Regular], [1.4616796874999998, -0.3920000058412552], 0.216)
```


# Parser

Parsing is done through the exported function `texparse` into nested `TeXExpr` objects forming a tree. The parser does not perform any operation to layout the elements, it only transforms them into a syntax tree.

The readme file in the `src/parser` folder contains more details about the inner working of the parser.

## Supported constructions

The table below contains the list of all supported LaTeX construction and their representation when parsed.

| Description | LaTeX example | Expression head | Fields |
|--|--|--|--|
| Accent | `\vec{v}` | `:accent` | `symbol, core` |
| Char | `x` | `:char` |
| Digit | `3` | `:digit` |
| Delimiter | `\left( \right)` | `:delimited` | `left_delimiter, content, right_delimiter` |
| Fraction | `\frac{}{}` | `:frac` | `numerator, denumerator` |
| Function | `\sin` | `:function` | `name` |
| Generic symbol | `ω` | `:symbol` | `unicode_char` |
| Group | `{ }` | `:group` | `elements...` |
| Inline math | `$ $` | `:inline_math` | `content` |
| Integral | `\int_a^b` | `:integral` | `symbol, low_bound, high_bound` |
| Math fonts | `\mathrm{}` | `:font` | `font_modifier, expr` |
| Punctuation | `!` | `:punctuation` |
| Simple delimiter | `(` | `:delimiter` |
| Square root | `\sqrt{2}` | `:sqrt` | `content` |
| Space | `\quad` | `:space` | `width` |
| Spaced symbol | `+` | `:spaced` | `symbol` |
| Subscript and superscript | `x_0^2` | `:decorated` | `core, subscript, superscript` |
| Symbol with script under and/or over it | `\sum_i^k` | `:underover` | `symbol, under, over` |

## Parser examples

### Basic examples

```julia
julia> texparse(raw"\beta_2")
TeXExpr :expr        
└─ TeXExpr :decorated
   ├─ TeXExpr :symbol
   │  └─ 'β'
   ├─ TeXExpr :digit
   │  └─ '2'
   └─ nothing
```

The Unicode input are supported at the parser level.

```julia
julia> expr = texparse(raw"β_2")
TeXExpr :expr
└─ TeXExpr :decorated
   ├─ TeXExpr :symbol
   │  └─ 'β'
   ├─ TeXExpr :digit
   │  └─ '2'
   └─ nothing
```

`TeXExpr` have the same `head` - `args` structure as the built-in `Expr`.

```julia
julia> expr.args[1].head
:decorated

julia> expr.args[1].args
3-element Vector{Any}:
 TeXExpr :symbol
└─ 'β'

 TeXExpr :digit
└─ '2'

 nothing
```

# Acknowledgement

The font inspector site [FontDrop!](https://fontdrop.info) has been invaluable for this package.