# UnicodeMath

[![Build Status](https://github.com/manuelbb-upb/UnicodeMath.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/manuelbb-upb/UnicodeMath.jl/actions/workflows/CI.yml?query=branch%3Amain)

A small Julia package inspired by the great LaTeX package 
[`unicode-math`](https://ctan.org/pkg/unicode-math?lang=en) that is available under 
[the LaTeX Project Public License 1.3c](https://ctan.org/license/lppl1.3c).

This project is not affiliated to `unicode-math`, the authors of `unicode-math` are 
not responsible for this code, and do not offer support.

## About
This module offers configurable Unicode glyph substitutions for Julia `Char`s or `AbstractString`s.
Specifically, the commands 
```
symup           # upright shape
symit           # italic/slanted shape
symbfup         # bold upright
symbfit         # bold italic
symsfup         # sans-serif upright
symsfit         # sans-serif italic
symbfsfup       # bold sans-serif upright
symtt           # mono spaced
symbb           # blackboard
symbbit         # blackboard italic
symcal          # caligraphic
symbfcal        # bold caligraphic
symfrak         # frakture
symbffrak       # bold frakture
```
take as input a `Char` and, if applicable, return the correspondingly styled `Char`, e.g., as defined in the
[Alphanumeric Symbols Unicode block](https://en.wikipedia.org/wiki/Mathematical_operators_and_symbols_in_Unicode#Mathematical_Alphanumeric_Symbols_block).
These commands have direct equivalents in the LaTeX package `unicode-math` and are similar to commands in 
[`UnicodeFun.jl`](https://github.com/SimonDanisch/UnicodeFun.jl):
```
to_blackboardbold
to_boldface
to_italic
to_caligraphic
to_frakture
to_latex
```

If there is no symbol defined for the requested style, the input `Char` is returned.
Input strings are parsed one `Char` at a time.

Internally, we define **alphabets**, e.g.
```
:latin      # lower case latin letters
:Latin      # upper case latin letters
:greek      # lower case greek letters
:Greek      # upper case greek letters
:num        # digits 0-9
```
Not every style is available for every character of every alphabet.
Please refer to the `unicode-math` manual for details, especially Table 7, or check the source file `apply_style.jl`.

Besides the direct substitution commands, there are also 
```
_sym        # normalization
symbf       # bold
symsf       # sans-serif
symbfsf     # bold sans-serif
```
These commands depend on a style configuration.
For example, `symbf` could return bold upright glyphs (`:bold_style=:upright`),
bold italic glyphs (`:bold_style=:italic`) or bold glyphs for which the shape is 
chosen according to the input shape (`:bold_style=:literal`).

The configuration is expressed by an `UCMConfig` object and is hierarchical.
The `math_style_spec` value (`:tex` (default), `:iso`, `:french`, `:upright`, `:literal`) induces
preconfigured values for `normal_style_spec`, `bold_style_spec`, `sans_style` as well as styling
information for the `:nabla` and `:partial` glyphs.
Both `normal_style_spec` and `bold_style_spec` in turn define a `normal_style` or `bold_style` 
values for the latin and greek alphabets.  
The defaults can be overwritten with the corresponding keyword arguments of the `UCMConfig`
constructor.
The following values are valid:
* `math_style_spec`: `:tex, :iso, :french, :upright, :literal`
* `normal_style_spec`: `:iso, :tex, :french, :upright, :literal` 
  or a `NamedTuple` with fields `:Greek, :greek, :Latin, :latin` and values `:upright, :italic, :literal`.
* `bold_style_spec`: `:iso, :tex, :upright, :literal`
  or a `NamedTuple` with fields `:Greek, :greek, :Latin, :latin` and values `:upright, :italic, :literal`.
* `sans_style`, `partial`, `nabla`: `:upright, :italic, :literal`

For `_sym` and the `sym` commands, a global configuration is set via `global_config!(cfg)`
or `global_config!(; kwargs...)`.
Alternatively, the lower level `apply_style` function can be called with configuration directly, as shown in the examples.

## Examples

### Basic Formatting
Use `apply_style` to format a `Char` or an `AbstractString` according to some configuration:
```julia-repl
julia> import UnicodeMath as UCM
julia> src = "BX 𝐵𝑋 ∇ 𝛁 𝜕 𝝏 𝜶𝜷 αβ 𝚪𝚵 𝜵 az 𝑎𝑧 𝛤𝛯 𝛻 ∂ 𝛛 ΓΞ 𝛼𝛽 1 𝜞𝜩 𝛂𝛃"
julia> cfg_tex = UCM.UCMConfig(; math_style_spec=:tex)
julia> UCM.apply_style(src, cfg_tex)
"𝐵𝑋 𝐵𝑋 ∇ 𝛁 𝜕 𝝏 𝜶𝜷 𝛼𝛽 𝚪𝚵 𝛁 𝑎𝑧 𝑎𝑧 ΓΞ ∇ 𝜕 𝝏 ΓΞ 𝛼𝛽 1 𝚪𝚵 𝜶𝜷"
```

The same keyword arguments that define `UCMConfig` can be given to apply style directly:
```julia-repl
julia> UCM.apply_style(src; math_style_spec=:iso)
"𝐵𝑋 𝐵𝑋 ∇ 𝛁 𝜕 𝝏 𝜶𝜷 𝛼𝛽 𝜞𝜩 𝛁 𝑎𝑧 𝑎𝑧 𝛤𝛯 ∇ 𝜕 𝝏 𝛤𝛯 𝛼𝛽 1 𝜞𝜩 𝜶𝜷"
julia> UCM.apply_style(src; math_style_spec=:upright)
"BX BX ∇ 𝛁 ∂ 𝛛 𝛂𝛃 αβ 𝚪𝚵 𝛁 az az ΓΞ ∇ ∂ 𝛛 ΓΞ αβ 1 𝚪𝚵 𝛂𝛃"
julia> UCM.apply_style(src; math_style_spec=:french)
"BX BX ∇ 𝛁 ∂ 𝛛 𝛂𝛃 αβ 𝚪𝚵 𝛁 𝑎𝑧 𝑎𝑧 ΓΞ ∇ ∂ 𝛛 ΓΞ αβ 1 𝚪𝚵 𝛂𝛃"
```

### Target Style

A target style can be forced. 
```julia-repl
julia> UCM.apply_style(src, :bfup; math_style_spec=:iso)
"𝐁𝐗 𝐁𝐗 𝛁 𝛁 𝛛 𝛛 𝛂𝛃 𝛂𝛃 𝚪𝚵 𝛁 𝐚𝐳 𝐚𝐳 𝚪𝚵 𝛁 𝛛 𝛛 𝚪𝚵 𝛂𝛃 𝟏 𝚪𝚵 𝛂𝛃"
```

The styles `:bf`, `:sf` and `:bfsf` still depend on the configuration:
```julia-repl
julia> UCM.apply_style(src, :bf; math_style_spec=:iso)
"𝑩𝑿 𝑩𝑿 𝛁 𝛁 𝝏 𝝏 𝜶𝜷 𝜶𝜷 𝚪𝚵 𝜵 𝒂𝒛 𝒂𝒛 𝜞𝜩 𝛁 𝝏 𝛛 𝜞𝜩 𝜶𝜷 𝟏 𝜞𝜩 𝛂𝛃"
```
In this example, bold glyphs have not been changed, otherwise bold italic glyphs for latin and greek letters are used.

### Global Commands
Apply default styling (`math_style_spec=:tex`), i.e., italic regular-weight letters, except for uppercase Greek letters, which are printed upright, and upright bold-weight letters, except for lowercase greek, which are printed slanted:
```julia-repl
julia> UCM._sym(src)
"𝐵𝑋 𝐵𝑋 ∇ 𝛁 𝜕 𝝏 𝜶𝜷 𝛼𝛽 𝚪𝚵 𝛁 𝑎𝑧 𝑎𝑧 ΓΞ ∇ 𝜕 𝝏 ΓΞ 𝛼𝛽 1 𝚪𝚵 𝜶𝜷"
```
Change the configuration:
```julia-repl
julia> UCM.global_config!(;normal_style_spec=:upright)
```
Now regular-weight letters are all upright:
```julia-repl
julia> UCM._sym(src)
"BX BX ∇ 𝛁 𝜕 𝝏 𝜶𝜷 αβ 𝚪𝚵 𝛁 az az ΓΞ ∇ 𝜕 𝝏 ΓΞ αβ 1 𝚪𝚵 𝜶𝜷"
```