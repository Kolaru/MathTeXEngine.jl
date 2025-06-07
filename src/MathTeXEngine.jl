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

end # module
