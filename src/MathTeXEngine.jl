module MathTeXEngine
# Adapted from matplotlib mathtext engine
# https://github.com/matplotlib/matplotlib/blob/master/lib/matplotlib/_mathtext.py

using AbstractTrees
using Automa
using FreeTypeAbstraction
using LaTeXStrings
using UnicodeFun

using DataStructures: Stack
using GeometryBasics: Point2f, Rect2f
using REPL.REPLCompletions: latex_symbols
using RelocatableFolders

import FreeTypeAbstraction:
    ascender, boundingbox, descender, get_extent, glyph_index,
    hadvance, inkheight, inkwidth,
    height_insensitive_boundingbox, leftinkbound, rightinkbound,
    topinkbound, bottominkbound

export TeXToken, tokenize
export TeXExpr, texparse, TeXParseError, manual_texexpr
export TeXElement, TeXChar, VLine, HLine, generate_tex_elements
export texfont, FontFamily, set_texfont_family!, get_texfont_family
export glyph_index

# Reexport from LaTeXStrings
export @L_str

include("parser/tokenizer.jl")
include("parser/texexpr.jl")
include("parser/commands_data.jl")
include("parser/commands_registration.jl")
include("parser/parser.jl")

include("engine/computer_modern_data.jl")
include("engine/new_computer_modern_data.jl")
include("engine/fonts.jl")
include("engine/layout_context.jl")
include("engine/texelements.jl")
include("engine/layout.jl")

include("UnicodeMath/UnicodeMath.jl")
import .UnicodeMath as UCM

# ## UnicodeMath
const _unicode_math_sym_commands_ref = Ref(true)
const _unicode_math_substitutions_ref = Ref(true)

# ### Fonts
# Define a mapping to use math font for most of the typesetting:
const _ucm_font_mapping = Dict(
    :text => :regular,
    :delimiter => :math,
    :digit => :math,
    :function => :regular,
    :punctuation => :math,
    :symbol => :math,
    :char => :math
)

"""
    unicode_math_fonts!(font_family)

Convenience function to configure math font to be used for anything but text and functions."""
function unicode_math_fonts!(ffm=nothing;)
    global _ucm_font_mapping
    _ffm = isnothing(ffm) ? get_texfont_family() : ffm
    for (k, v) in pairs(_ucm_font_mapping)
        _ffm.font_mapping[k] = v
    end
    if !isnothing(ffm)
        set_texfont_family!(_ffm)
    end    
    return _ffm
end

"""
    unicode_math_config!(;
        enable_sym_commands=true,
        enable_substitutions=true,
        math_style=:tex,
        normal_style=nothing,
        bold_style=nothing,
        sans_style=nothing,
        partial=nothing,
        nabla=nothing
    )
Convenience function to globally configure the substitutions unicode character 
substitutions performed by `UnicodeMath`.
Substitutions 
`math_style` sets defaults which can be overriden individually using the other 
keyword argument."""
function unicode_math_config!(;
    enable_sym_commands=true,
    enable_substitutions=true,
    math_style=:tex,
    normal_style=nothing,
    bold_style=nothing,
    sans_style=nothing,
    partial=nothing,
    nabla=nothing
)
    global _unicode_math_substitutions_ref, _unicode_math_sym_commands_ref
    _unicode_math_sym_commands_ref[] = enable_sym_commands
    _unicode_math_substitutions_ref[] = enable_substitutions
    UCM.global_config!(; math_style, normal_style, bold_style, sans_style, partial, nabla)
    return nothing
end

# ### Command Registration
# #### Style Commands

# command_definitions["\\_"] = (TeXExpr(:punctuation, '_'), 0)

for style_symb in UCM.all_styles
    com_str = "\\sym$(style_symb)"
    command_definitions[com_str] = (TeXExpr(:sym, style_symb), 1)
end

for (cmd_symb, ucm_char) in pairs(UCM.extra_commands)
    symbol = ucm_char.char
    symbol_expr = TeXExpr(:symbol, symbol)

    if !haskey(symbol_to_canonical, symbol)
        symbol_to_canonical[symbol] = symbol_expr
    end

    com_str = "\\$(cmd_symb)"
    # Separate case for symbols that have multiple valid commands
    if !haskey(command_definitions, com_str)
        command_definitions[com_str] = (symbol_expr, 0)
    end
end

### Parser -- TeXExpr
function TeXExpr(head::Symbol, args::Vector)
    global _unicode_math_sym_commands_ref

    ## like with `\mathbf` etc. recursively apply `\symbf` etc. at parse time:
    if _unicode_math_sym_commands_ref[] && (
        head == :sym &&
        length(args) == 2 && 
        args[1] in UCM.all_styles
    )
        style_symb, content = args
        return leafmap(content) do leaf
            sym = only(leaf.args)
            return TeXExpr(:ucm_symbol, UCM.sym_style(sym, style_symb))
        end
    end
    
    #=
    ## we can also stylize other characters at parse-time;
    ## feels a bit hacky as `_ucm_stylize` takes into account the font-family to determine
    ## which symbols to investigate;
    ## alternatively, change `TeXChar` in the layouting phase; 
    ## this would require marking symbols stylized by `\symXX` commands so that they are 
    ## not changed anymore...
    if length(args) == 1
        arg = only(args)
        if arg isa Char
            arg = _ucm_stylize(head, arg)
            args = [arg,]
        end
    end

    Disabled because we want to distinguish normal characters (not wrapped by `\symXXX`)
    depending on state, and only stylize with `:inline_math`.
    To not change symbols already stylized, we use `:ucm_symbol` above.
    This is a new (internal) leaf type that is respected in `TeXChar`.
    =#

    ## redirect to original method:
    return Base.invoke(TeXExpr, Tuple{Any, Vector}, head, args)
end

#=
function TeXExpr(head::Symbol, arg::Char)
    #=
    ## stylize unicode characters at parse-time:
    arg = _ucm_stylize(head, arg)
    =#
    return Base.invoke(TeXExpr, Tuple{Any, Any}, head, arg)
end
=#

function _ucm_stylize(head, char, _ffm = nothing)
    global _unicode_math_substitutions_ref
    
    !(_unicode_math_substitutions_ref[]) && return char

    if head in (:char, :delimiter, :digit, :punctuation, :symbol)
        ffm = isnothing(_ffm) ? get_texfont_family() : _ffm
        if get(ffm.font_mapping, head, :notmath) == :math
            char = UCM.sym_style(char)
        end
    end
    return char
end

end # module
