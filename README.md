# MathTeXEngine

This is a work in progress package aimed at providing a pure Julia engine for LaTeX math mode. It is composed of two main parts: a LaTeX parser and a LaTeX engine, both only for LaTeX math mode.

# Main features

- Parsing of (possibly nested) LaTeX expression and creation of a layout for them.
- Equivalence between traditional LaTeX commands and their unicode input equivalent.
- Pure julia.

# Engine

The main use of the package is through `generate_tex_elements` taking a LaTeX string as input and return a list of tuples `(TeXElement, position, scale)` where `TeXElement` is one of the following:

- `TeXChar(char, font)` a unicode character to be displayed in a specific font.
- `VLine(height, thickness)` a vertical line.
- `HLine(width, thickness)` an horizontal line.

This contains enough information to then draw everything with any plotting package that can draw arbitrary glyph in arbitrary font. The position is the origin of the character according to `FreeType`.

Positions and scales are given for a font size of `1`. For bigger font size they simply need to be multiplied by the font size.

The engine should support every construction the parser does (see below).

Currently the only font set supported is New Computer Modern.

## Engine examples

### Basic examples

```julia
julia> using MathTeXEngine

julia> using LaTeXStrings

julia> generate_tex_elements(L"\beta_2")
2-element Vector{Any}:
 (TeXChar 'β' [U+03B2 in NewComputerModern Math - Regular], [0.0, 0.0], 1.0)
 (TeXChar '2' [U+0032 in NewComputerModern - 10 Regular], [0.5580000281333923, -0.20000000298023224], 0.6)
```

Note that the `LaTeXStrings` package must be loaded for the use of the `L"..."` macro. MathTeXEngine can work with strings directly too.

```julia
julia> generate_tex_elements(raw"\beta_2")
2-element Vector{Any}:
 (TeXChar 'β' [U+03B2 in NewComputerModern Math - Regular], [0.0, 0.0], 1.0)
 (TeXChar '2' [U+0032 in NewComputerModern - 10 Regular], [0.5580000281333923, -0.20000000298023224], 0.6)  
```

The `raw"..."` macro is used to avoid having to repeat backslash, but generate normal strings. Using `LaTeXString` can be useful to convey the information these strings are expected to be parsed as LaTeX.

Also note that Unicode character can be used directly and are equivalent to their command.

```julia
julia> generate_tex_elements(raw"β_2")
2-element Vector{Any}:
 (TeXChar 'β' [U+03B2 in NewComputerModern Math - Regular], [0.0, 0.0], 1.0)
 (TeXChar '2' [U+0032 in NewComputerModern - 10 Regular], [0.5580000281333923, -0.20000000298023224], 0.6)
```

Using the inline math mode with `$...$` is supported. However, currently, line breaks or line wraps are not supported.

```julia
julia> generate_tex_elements(L"b $β_2$")
4-element Vector{Any}:
 (TeXChar 'b' [U+0062 in NewComputerModern - 10 Regular], [0.0, 0.0], 1.0)
 (TeXChar ' ' [U+0020 in NewComputerModern - 10 Regular], [0.5559999942779541, 0.0], 1.0)
 (TeXChar 'β' [U+03B2 in NewComputerModern Math - Regular], [0.8889999985694885, 0.0], 1.0)
 (TeXChar '2' [U+0032 in NewComputerModern - 10 Regular], [1.4470000267028809, -0.20000000298023224], 0.6)
```

### VLine and Hline

Some LaTeX construct, mainly square roots and fractions generate additional lines that are not representing a character. The `HLine` or `VLine` object contain all information needed to draw the line correctly.

```julia
julia> elements = generate_tex_elements(L"\frac{1}{2}")
3-element Vector{Any}:
 (HLine{Float64}(0.6144999861717224, 0.04), [0.0, 0.19550000131130219], 1.0)
 (TeXChar '1' [U+0031 in NewComputerModern - 10 Regular], [0.1422499716281891, 0.41099998354911804], 1.0)
 (TeXChar '2' [U+0032 in NewComputerModern - 10 Regular], [0.10774999856948853, -0.6859999895095825], 1.0)

julia> hline = elements[1][1]
HLine{Float64}(0.6144999861717224, 0.04)

julia> hline.width
0.6144999861717224

julia> hline.thickness
0.04
```

### Nested expressions

A flat list is always returned even if the LaTeX expression is deeply nested.

```julia
julia> generate_tex_elements(L"A_{B_{C_D}}")
4-element Vector{Any}:
 (TeXChar 'A' [U+0041 in NewComputerModern - 10 Italic], [0.0, 0.0], 1.0)
 (TeXChar 'B' [U+0042 in NewComputerModern - 10 Italic], [0.7429999709129333, -0.20000000298023224], 0.6)
 (TeXChar 'C' [U+0043 in NewComputerModern - 10 Italic], [1.165399968624115, -0.3200000047683716], 0.36)
 (TeXChar 'D' [U+0044 in NewComputerModern - 10 Italic], [1.4231599760055542, -0.3920000058412552], 0.216)
```


# Parser

Parsing is done through the exported function `texparse` into nested `TeXExpr` objects forming a tree. The parser does not perform any operation to layout the elements, it only transforms them into a syntax tree.

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
| Integral | `\int_a^b` | `:integral` | `symbol, low_bound, high_bound` |
| Punctuation | `!` | `:punctuation` |
| Simple delimiter | `(` | `:delimiter` |
| Square root | `\sqrt{2}` | `:sqrt` | `content` |
| Space | `\quad` | `:space` | `width` |
| Spaced symbol | `+` | `:spaced` | `symbol` |
| Subscript and superscript | `x_0^2` | `:decorated` | `core, subscript, superscript` |
| Symbol with script under and/or over it | `\sum_i^k` | `:underover` | `symbol, under, over` |

## To be implemented

| Description | LaTeX example | Head | Fields | Comment |
|--|--|--|--|--|
| Basic font | `\mathrm{d}` | `:font` | `fontstyle, content` |

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

`TeXExpr` have the same `head` - `args` structure than the built-in `Expr`.

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