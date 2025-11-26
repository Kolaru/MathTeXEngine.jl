"""
    UnicodeMath

A Julia package inspired by the great LaTeX package `unicode-math`.
As a user you should care mainly about [`apply_style`](@ref) and the globally
configured functions [`_sym`](@ref) and `symbf`, `symit`, etc.
The latter are configured with [`global_config!`](@ref)
"""
module UnicodeMath
#=
# Typography Terminology

When it comes to typography, common concepts have different names in different contexts.
Here is what Wikipedia has to say about “typeface” and “font”:

> A typeface (or font family) is a design of letters, numbers and other symbols, 
> to be used in printing or for electronic display.
> Most typefaces include variations in size (e.g., 24 point), weight (e.g., light, bold), 
> slope (e.g., italic), width (e.g., condensed), and so on. 
> Each of these variations of the typeface is a font.

  Wikipedia contributors, "Typeface," Wikipedia, The Free Encyclopedia, 
  https://en.wikipedia.org/w/index.php?title=Typeface&oldid=1309901840 
  (accessed September 24, 2025).

E.g., “Times” is a typeface family, and “Times Roman” and “Times Italic” are 
typefaces/font families within that typeface, and “Times Roman 10” is a font within 
the typeface “Times Roman”.

According to https://texdoc.org/serve/fntguide/0, LaTeX uses 
* “family” to refer to a typeface/font family, e.g. “CMU Serif”,
* “series” for weight and spacing,
* “shape” is the form of the letters, e.g., “italic” or “upright”.
Together with “size”, a font can be selected.

For maths, commands such as `\mathbf` are defined via
`\DeclareMathAlphabet {⟨math-alph⟩} {⟨encoding⟩} {⟨family⟩} {⟨series⟩} {⟨shape⟩}`.
Hence, a “math-alphabet” is really just a specific font 
(that has glyphs for a subset of mathematical characters).
In `unicode-math`, the new wrapper command is aptly named `\setmathfontface`.
It is okay to use “alphabet” in a hand-wavy manner, because even Wikipedia and 
package documentation does so.

> Every typeface is a collection of glyphs, each of which represents an individual 
> letter, number, punctuation mark, or other symbol. 
> The same glyph may be used for characters from different writing systems, 
> e.g. Roman uppercase A looks the same as Cyrillic uppercase А and Greek uppercase alpha (Α). 
> There are typefaces tailored for special applications, such as cartography, astrology or mathematics.

  Wikipedia contributors, "Typeface," Wikipedia, The Free Encyclopedia, 
  https://en.wikipedia.org/w/index.php?title=Typeface&oldid=1309901840 
  (accessed September 24, 2025).

In accordance with https://en.wikipedia.org/wiki/Glyph, the concept of a letter, number, etc.
is a grapheme-like unit, or an (abstract) character.
A glyph is its graphical representation.

In Unicode, collections of characters often form 
[scripts](https://en.wikipedia.org/wiki/Script_(Unicode)),
and usually, style information is not encoded in scripts.

Except for math charactes, **which do not constitute a script**.
Unicode has various styles for many mathematical characters.
For example, the abstract character “A” has styled variants
“𝐀” (MATHEMATICAL BOLD CAPITAL A) or “𝐴” (MATHEMATICAL ITALIC CAPITAL A).
Usually style variants (series or shape) would be provided by different fontfaces,
but math fonts contain these stylized variants themselves.

The LaTeX package `unicode-math` has commands like `\symbf` that map between different
styles and emulate legacy commands, but do not switch fontfaces for mathematical characters
that have style variants.

# ## Package Naming Conventions 

We mimic some of the functionality of `unicode-math` for string formatting in Julia.
To this end, we define our own “alphabets”, which are sets of abstract characters.
E.g. `:num` are numbers, `:latin` are lowercase Latin characters, and `:Greek` 
are uppercase Greek characters. 
There are also singleton sets to allow for granular configuration.

Within an alphabet each abstract character has a unique “name”, i.e. "1" or "a" or "Alpha".

Then there are styles, i.e., combinations of series and shape properties.
A math font can provide glyphs for styles defined in `base_styles` for the characters in our 
alphabets.
There are styles like `:bf` (bold) or `:sf` (sans-serif) for which the mapping is 
more complicated.
We might wish to have bold italic letters by default, i.e., `:bf` should alias `:bfit`
depending on a (global) configuration.

For us, specific fonts are not relevant, so we call the Unicode characters that are mapped 
“glyphs”.
It is unavoidable that sometimes the terms “character”/“glyph”/“symbol” are used 
synonymously, but hopefully context disolves confusion.
It doesn't help that Julia has types `Symbol` and `Char`.
Indeed, a glyph is represented by a `Char`.
=#

# # Simple Global Definitions
# External Dependencies:
import UnPack: @unpack

# Simple Type Constants:
const Nothymbol = Union{Nothing, Symbol}
const SpecTup = @NamedTuple{Greek::Symbol, greek::Symbol, Latin::Symbol, latin::Symbol}

# # Extra LaTeX Commands
# Include standalone file defining `extra_commands::Dict{Symbol,UCMCommand}`.
# The dict has custom commands defined in `unicode-math` 
# which are extracted from the LaTeX source code.  
include("extra_commands.jl")  # `extra_commands`

# # Styling
# Symbols for base styles  (excluding derived styles like `bf`, `sf`, `bfsfup`):
const base_styles = (
    :up, :it,  
    :bfup, :bfit, 
    :sfup, :sfit, 
    :bfsfup, :bfsfit, 
    :tt, 
    :bb, :bbit,
    :cal, :bfcal, 
    :frak, :bffrak
)

# Symbols for every possible style:
const all_styles = (base_styles..., :bf, :sf, :bfsf)

# Alphabet definitions:
include("ucmchars.jl")
const Glyph = Union{Char, UCMChar}

# A nested dict that is needed for mapping between styles:
const ucmchars_by_alphabet_style_name = all_ucmchars()
# A dict mapping `Char`s to `UCMChar`s (which store meta data):
const chars_to_ucmchars = inverse_ucm_dict(ucmchars_by_alphabet_style_name)

# The basic styling command, needing configuration:
include("apply_style.jl")

# ## Global Styling Commands
# Prepare defaults for global styling commands:
const default_config_dicts = config_dicts()
const default_substitutions = default_config_dicts.substitutions
const default_aliases = default_config_dicts.aliases

# Store internal references so that the actual config dicts can be modified:
const default_substitutions_ref = Ref(default_substitutions)
const default_aliases_ref = Ref(default_aliases)

"""
    global_config!(; kwargs...)
    global_config!(cfg::UCMConfig)

Configure how styling functions such as `symbf` act.
Take the same keyword arguments as [`UCMConfig`](@ref).
"""
function global_config!(args...; kwargs...)
    global default_substitutions_ref, default_aliases_ref
    s, a = config_dicts(args...; kwargs...)
    default_substitutions_ref[] = s
    default_aliases_ref[] = a
    return nothing
end

# Basic global styling command:
"""
    _sym(glyph::Union{Char, UCMChar, AbstractString}; is_styled=false)
    _sym(glyph::Union{Char, UCMChar, AbstractString}, trgt_style::Symbol; is_styled=false)

Try to style `glyph` according to global configuration, which is set by 
[`global_config!`](@ref).

## `is_styled` keyword argument
The special keyword argument `is_styled` defines how unspecific target styles 
(like `:bf` or `sf`) are handled.
In absence of a `trgt_style`, it also determines if upright or italic glyphs are “normalized”.

### Without `trgt_style`
If there is no explicit `trgt_style`, then `trgt_style` matches the style of `glyph`.
E.g., `a` results in `trgt_style = :up` and `𝑎` in `trgt_style = :it`.  
If `is_styled == false`, then `glyph` will be normalized according to configuration.  
In `:iso` style, both `a` and `𝑎` should be styled to `𝑎`.
If `is_styled == true`, the styling is a no-op in this case.

### With `trgt_style`
If `is_styled == true`, then an italic glyph will become bolditalic for `trgt_style == :bf`,
independent of the configuration.
If `is_styled == false`, then the glyph is considered “typed by the user” and the bold style
depends on the configuration.
"""
function _sym end

function _sym(x::Union{AbstractString,Glyph}, trgt_style::Symbol...; is_styled=false)
    global default_substitutions_ref, default_aliases_ref

    return apply_style(
        x,
        default_substitutions_ref[],
        default_aliases_ref[],
        trgt_style...;
        is_styled
    )
end

# Derive specific styling functions like `symbf`:
for sn in all_styles
    f = Symbol("sym", sn)
    @eval begin
        """
            $($(Meta.quot(f)))(glyph::Union{Char, UCMChar, AbstractString}; is_styled=false)

        If applicable, return a new `Char` with style fitting `:$($(Meta.quot(sn)))`.
        For information on the `is_styled` keyword argument, 
        see [`apply_style`](@ref) or [`_sym`](@ref)."""
        function $(f)(x::Union{AbstractString, Glyph}; is_styled=false)
            return _sym(x, $(Meta.quot(sn)); is_styled)
        end
    end
end

end#module