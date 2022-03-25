module MathTeXEngine
# Adapted from matplotlib mathtext engine
# https://github.com/matplotlib/matplotlib/blob/master/lib/matplotlib/_mathtext.py

using AbstractTrees
using Automa
using FreeTypeAbstraction
using LaTeXStrings

using Automa.RegExp: @re_str
using DataStructures: Stack
using GeometryBasics: Point2f, Rect2f
using REPL.REPLCompletions: latex_symbols
using RelocatableFolders

import FreeTypeAbstraction:
    ascender, boundingbox, descender, get_extent, hadvance, inkheight, inkwidth,
    height_insensitive_boundingbox, leftinkbound, rightinkbound,
    topinkbound, bottominkbound

const re = Automa.RegExp

export TeXExpr, texparse
export TeXElement, TeXChar, VLine, HLine, generate_tex_elements
export get_font, get_fontpath

# Reexport from LaTeXStrings
export @L_str

include("parser/texexpr.jl")
include("parser/commands_data.jl")
include("parser/commands_registration.jl")
include("parser/parser.jl")

include("engine/computer_modern_data.jl")
include("engine/fonts.jl")
include("engine/layout_context.jl")
include("engine/texelements.jl")
include("engine/layout.jl")

end # module
