const EMPTY_DICT = Base.ImmutableDict{Nothing, Nothing}()

# There are several parameters that influence how glyphs are mapped.

# A **normal style** defines how a user typed character in a standard style 
# (`:up` or `it`) is mapped to glyphs.
# `:italic` forces italic glyphs, `:upright` forces upright glyphs,
# `:literal` does not change style.
# Similarly, a **bold style** specifies whether or not bold glyphs are upright or
# slanted. Same for **sans style**.
# Special alphabets (`partial`, `nabla`) can be configured, too. 
#
# A normal style specification (:iso, :tex, ...) assigns normal styles to glyphs from 
# certain alphabets, and a bold style specification assigns bold styles to glyphs from 
# certain alphabets.
#
# On the top level, a math style specification sets normal and bold style specifications 
# and styles for the other alphabets.

"""
    UCMConfig(; math_style_spec = :tex, kwargs...)

Styling configuration. The keywords `normal_style_spec`, `bold_style_spec`, `sans_style`,
`partial` and `nabla` can be used to override defaults set by `math_style_spec`.
"""
Base.@kwdef struct UCMConfig
    math_style_spec :: Nothymbol = :tex
    ## overrides
    normal_style_spec :: Union{SpecTup,Nothymbol} = nothing
    bold_style_spec :: Union{SpecTup,Nothymbol} = nothing
    sans_style :: Nothymbol = nothing
    partial :: Nothymbol = nothing
    nabla :: Nothymbol = nothing
end

"""
    apply_style(cfg::UCMConfig, glyph::Char; is_styled=false)
    apply_style(cfg::UCMConfig, glyph::Char, trgt_style::Symbol; is_styled=false)
    apply_style(glyph::Char; is_styled=false, kwargs...)
    apply_style(glyph::Char, trgt_style::Symbol; is_styled=false, kwargs...)

Stylize glyph according to configuration `cfg` or keyword arguments `kwargs...`.

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
function apply_style end

function apply_style(ch::Char, args...; kwargs...)
    ucm_ch = get(chars_to_ucmchars, ch, nothing)
    isnothing(ucm_ch) && return ch
    _ucm_ch = apply_style(ucm_ch, args...; kwargs...)
    return _ucm_ch.glyph
end

function apply_style(
    ucm_ch::UCMChar, cfg::UCMConfig, trgt_style::Symbol...;
    is_styled=false
)
    @unpack math_style_spec, normal_style_spec, bold_style_spec, sans_style, partial, nabla = cfg
    @unpack substitutions, aliases = config_dicts(; 
        math_style_spec, normal_style_spec, bold_style_spec, sans_style, partial, nabla)
    return apply_style(ucm_ch, substitutions, aliases, trgt_style...; is_styled)
end

function apply_style(
    ucm_ch::UCMChar, trgt_style::Symbol...; 
    is_styled=false, kwargs...
)
    cfg = UCMConfig(; kwargs...)
    return apply_style(ucm_ch, cfg, trgt_style...; is_styled)
end

function apply_style(
    ucm_ch::UCMChar, substitutions::AbstractDict, aliases::AbstractDict;
    is_styled=false
)
    trgt_style = ucm_ch.style
    return apply_style(ucm_ch, substitutions, aliases, trgt_style; is_styled)
end

function apply_style(
    ucm_ch::UCMChar, substitutions::AbstractDict, aliases::AbstractDict, trgt_style::Symbol;
    is_styled=false,
)
    if !is_styled
        ucm_ch = UCMChar(
            ucm_ch.name, ucm_ch.alphabet, _typed_style(ucm_ch.style), ucm_ch.glyph)
    end

    subs_alphabet = get(substitutions, ucm_ch.alphabet, EMPTY_DICT)
    subs_current_style = get(subs_alphabet, ucm_ch.style, EMPTY_DICT)
    trgt_style = get(subs_current_style, trgt_style, trgt_style)
    
    alisaes_alphabet = get(aliases, ucm_ch.alphabet, EMPTY_DICT)
    trgt_style = get(alisaes_alphabet, trgt_style, trgt_style)
    
    return _choose_style(ucm_ch, trgt_style)
end

function apply_style(
    io::IO, ch::Glyph, args...; kwargs...
)
    print(io, apply_style(ch, args...; kwargs...))
end

function apply_style(io::IO, str::AbstractString, args...; kwargs...)
    cls = ch -> apply_style(ch, args...; kwargs...)
    for ch in str
        print(io, cls(ch))
    end
end

function apply_style(str::AbstractString, args...; kwargs...)
    sprint() do io
        apply_style(io, str, args...; kwargs...)
    end
end

function _typed_style(symb)
    _symb = if symb == :up
        ## check normal style 
        :UP
    elseif symb == :it
        ## check normal style 
        :IT
    elseif symb == :bfup
        ## check bold style 
        :BFUP
    elseif symb == :bfit
        ## check bold style 
        :BFIT
    elseif symb == :sfup
        ## check sans style 
        :SFUP
    elseif symb == :sfit
        ## check sans style 
        :SFIT
    elseif symb == :bfsfup
        ## check sans style 
        :BFSFUP
    elseif symb == :bfsfit
        ## check sans style 
        :BFSFIT
    else
        symb
    end
    return _symb
end

## helper function -- given `ucm_ch::UCMChar` and a target style like `:bf`,
## return the corresponding `UCMChar` from the styled alphabet, if it is available for `ucm_ch`.
function _choose_style(ucm_ch, style_symb)
    _ucm_ch = _choose_style(ucm_ch.name, ucm_ch.alphabet, style_symb)
    isnothing(_ucm_ch) && return ucm_ch
    return _ucm_ch
end

function _choose_style(name_str, alphabet_symb, style_symb)
    global ucmchars_by_alphabet_style_name
    ## check if the alphabet is key for outer dict:
    ucmchars_by_style_name = get(ucmchars_by_alphabet_style_name, alphabet_symb, nothing)
    isnothing(ucmchars_by_style_name) && return nothing

    ## check if target style is key in 2nd level:
    ucmchars_by_name = get(ucmchars_by_style_name, style_symb, nothing)
    isnothing(ucmchars_by_name) && return nothing

    ## inner dict has `name => UCMChar` entries for target style.
    ## return value if it exists
    ucm_ch = get(ucmchars_by_name, name_str, nothing)
    return ucm_ch
end

function parse_config(;
    math_style_spec=:tex,
    normal_style_spec=nothing,
    bold_style_spec=nothing,
    sans_style=nothing,
    partial=nothing,
    nabla=nothing
)
    cfg = if math_style_spec == :iso
        (;
            nabla = :upright,
            partial = :italic,
            normal_style_spec = :iso,
            bold_style_spec = :iso,
            sans_style = :italic
        )
    elseif math_style_spec == :tex
        (;
            nabla = :upright,
            partial = :italic,
            normal_style_spec = :tex,
            bold_style_spec = :tex,
            sans_style = :upright
        )
     elseif math_style_spec == :french
        (;
            nabla = :upright,
            partial = :upright,
            normal_style_spec = :french,
            bold_style_spec = :upright,
            sans_style = :upright
        )
    elseif math_style_spec == :upright
        (;
            nabla = :upright,
            partial = :upright,
            normal_style_spec = :upright,
            bold_style_spec = :upright,
            sans_style = :upright
        )
   else
        (;
            nabla = :literal,
            partial = :literal,
            normal_style_spec = :literal,
            bold_style_spec = :literal,
            sans_style = :literal
        )
    end
    normal_style_spec = isnothing(normal_style_spec) ? cfg.normal_style_spec : normal_style_spec
    bold_style_spec = isnothing(bold_style_spec) ? cfg.bold_style_spec : bold_style_spec
    sans_style = isnothing(sans_style) ? cfg.sans_style : sans_style
    partial = isnothing(partial) ? cfg.partial : partial
    nabla = isnothing(nabla) ? cfg.nabla : nabla
    return (; nabla, partial, normal_style_spec, bold_style_spec, sans_style)
end

function config_dicts(cfg::UCMConfig)
    @unpack math_style_spec, normal_style_spec, bold_style_spec, sans_style, partial, nabla = cfg
    return config_dicts(; 
        math_style_spec, normal_style_spec, bold_style_spec, sans_style, partial, nabla)
end

function config_dicts(; kwargs...)
    cfg = parse_config(; kwargs...)
    substitutions = alphabet_substitutions(; cfg...)

    aliases_num = Dict(
        :it => :up,
        :bf => :bfup,
        :bfit => :bfup,
        :sf => :sfup,
        :sfit => :sfup,
        :bfsf => :bfsfup,
        :bfsfit => :bfsfup,
        :bbit => :bb    # this is different from LaTeX package
    )
    aliases = Dict(
        :num => aliases_num
    )
    
    return (; substitutions, aliases)
end

# For a given alphabet, we generate a “substitutions dict (of dicts)” to map between styles.
# It is a bit verbose, but simple and we avoid recursion this way:
function alphabet_substitutions(;
    normal_style_spec,
    bold_style_spec,
    sans_style,
    partial,
    nabla
)
    ns = parse_normal_style_spec(normal_style_spec)
    bs = parse_bold_style_spec(bold_style_spec)
    subs = Dict(
        :num => _subtitutions_dict(; normal_style=:upright, bold_style=:upright, sans_style=:upright),
        :Greek => _subtitutions_dict(; normal_style=ns.Greek, bold_style=bs.Greek, sans_style),
        :greek => _subtitutions_dict(; normal_style=ns.greek, bold_style=bs.greek, sans_style),
        :Latin => _subtitutions_dict(; normal_style=ns.Latin, bold_style=bs.Latin, sans_style),
        :latin => _subtitutions_dict(; normal_style=ns.latin, bold_style=bs.latin, sans_style),
        :partial => _subtitutions_dict(; normal_style=partial, bold_style=partial, sans_style=partial),
        :Nabla => _subtitutions_dict(; normal_style=nabla, bold_style=nabla, sans_style=nabla),
    )
    subs[:dotless] = subs[:latin]
    
    return subs
end

# A normal style (:iso, :tex, :french, :upright) assigns normal style specification to alphabets:
function parse_normal_style_spec(normal_style_spec::Symbol)
    normal_style_ntup = if normal_style_spec == :iso
        (;
            Greek = :italic,
            greek = :italic,
            Latin = :italic,
            latin = :italic
        )
    elseif normal_style_spec == :tex
        (;
            Greek = :upright,
            greek = :italic,
            Latin = :italic,
            latin = :italic
        )
    elseif normal_style_spec == :french
        (;
            Greek = :upright,
            greek = :upright,
            Latin = :upright,
            latin = :italic
        )
    elseif normal_style_spec == :upright
        (;
            Greek = :upright,
            greek = :upright,
            Latin = :upright,
            latin = :upright,
        )
    else
        (;
            Greek = :literal,
            greek = :literal,
            Latin = :literal,
            latin = :literal,
        )
    end
    return normal_style_ntup
end
function parse_normal_style_spec(spec::SpecTup)
    for symb in values(spec)
        @assert symb in (:literal, :upright, :italic)
    end
    return spec
end
function parse_normal_style_spec(spec)
    error("Normal style specification must be a symbol or of type $(SpecTup)")
end

function parse_bold_style_spec(
    bold_style_spec::Symbol
)
    bold_style_ntup = if bold_style_spec == :iso
        (;
            Greek = :italic,
            greek = :italic,
            Latin = :italic,
            latin = :italic
        )
    elseif bold_style_spec == :tex
        (;
            Greek = :upright,
            greek = :italic,
            Latin = :upright,
            latin = :upright
        )
    elseif bold_style_spec == :upright
        (;
            Greek = :upright,
            greek = :upright,
            Latin = :upright,
            latin = :upright,
        )
    else
        (;
            Greek = :literal,
            greek = :literal,
            Latin = :literal,
            latin = :literal,
        )
    end
    return bold_style_ntup
end
function parse_bold_style_spec(spec::SpecTup)
    for symb in values(spec)
        @assert symb in (:literal, :upright, :italic)
    end
    return spec
end
function parse_bold_style_spec(spec)
    error("Bold style specification must be a symbol or of type $(SpecTup)")
end

function _subtitutions_dict(;
    normal_style=:literal,
    bold_style=:literal,
    sans_style=:literal
)
    ## `subs_up`: how glyphs with an upright style should be transformed if we request
    ## a certain style, which are keys of this dict
    subs_up = Dict( sn => sn for sn = base_styles )
    subs_up[:bf] = :bfup
    subs_up[:sf] = :sfup
    subs_up[:bfsf] = :bfsfup

    subs_UP = copy(subs_up)
    subs_UP[:up] = normal_style == :italic ? :it : (normal_style == :upright ? :up : :up)
    subs_UP[:bf] = if bold_style == :upright   ### expanded for illustration purposes
        ### bold_style forces upright bold 
        :bfup 
    elseif bold_style == :italic 
        ### bold_style forces italic bold 
        :bfit 
    else
        ### bold_style does not care about slanting, we have an `:up` glyph, so keep it that way
        :bfup
    end
    subs_UP[:sf] = sans_style == :upright ? :sfup : (sans_style == :italic ? :sfit : :sfup)
    subs_UP[:bfsf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)

    ## `subs_it`: transformations for italic glyphs
    subs_it = Dict( sn => sn for sn = base_styles )
    subs_it[:bf] = :bfit
    subs_it[:sf] = :sfit
    subs_it[:bfsf] = :bfsfit
    subs_it[:bb] = :bbit

    subs_IT = copy(subs_it)
    subs_IT[:it] = normal_style == :italic ? :it : (normal_style == :upright ? :up : :it)
    subs_IT[:bf] = bold_style == :upright ? :bfup : (bold_style == :italic ? :bfit : :bfit)
    subs_IT[:sf] = sans_style == :upright ? :sfup : (sans_style == :italic ? :sfit : :sfit)
    subs_IT[:bfsf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)
    #subs_it[:bb] = :bbit   # `blackboard_style`?
   
    ## `sub_bfup`: transformations for bold upright glyphs
    subs_bfup = Dict(
        :up => :bfup,   # no-op
        :bfup => :bfup, # no-op
        :bf => :bfup,   # no-op
        :it => :bfit,
        :bfit => :bfit,
        :sfup => :bfsfup,
        :bfsf => :bfsf,
        :bfsfup => :bfsfup,
        :sfit => :bfsfit,
        :bfsfit => :bfsfit,
        :cal => :bfcal,
        :frak => :bffrak,
    )
    subs_BFUP = copy(subs_bfup)
    subs_BFUP[:bf] = subs_BFUP[:bfup] = bold_style == :upright ? :bfup : (bold_style == :italic ? :bfit : :bfup)
    subs_BFUP[:bfsf] = subs_bfup[:sf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)

    ## `sub_bfit`: transformations for bold italic glyphs
    subs_bfit = Dict(
        :bf => :bfit,   # no-op
        :bfit => :bfit, # no-op
        :it => :bfit,   # no-op
        :up => :bfup,   # undo italization
        :bfup => :bfup, # undo italization
        :sfit => :bfsfit,
        :bfsf => :bfsfit,
        :bfsfit => :bfsfit,
        :sfup => :bfsfup,
        :bfsfup => :bfsfup,
    )
    subs_BFIT = copy(subs_bfit)
    subs_BFIT[:bf] = subs_BFIT[:bfit] = bold_style == :upright ? :bfup : (bold_style == :italic ? :bfit : :bfit)
    subs_BFIT[:bfsf] = subs_bfit[:sf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)

    ## `sub_bfit`: transformations for sans-serif upright glyphs
    subs_sfup = Dict(
        :sf => :sfup,   # no-op
        :sfup => :sfup, # no-op
        :up => :sfup,   # no-op
        :it => :sfit,
        :sfit => :sfit,
        :bfup => :bfsfup,
        :bfsf => :bfsfup,
        :bfsfup => :bfsfup,
        :bfit => :bfsfit,
        :bfsfit => :bfsfit,
    )
    subs_SFUP = copy(subs_sfup)
    subs_SFUP[:sfup] = sans_style == :upright ? :sfup : (sans_style == :italic ? :sfit : :sfup)
    subs_sfup[:bf] = subs_SFUP[:bfsf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)

    ## `sub_bfit`: transformations for sans-serif italic glyphs
    subs_sfit = Dict(
        :sf => :sfit,   # no-op
        :sfit => :sfit, # no-op
        :it => :sfit,   # no-op
        :up => :sfup,
        :sfup => :sfup,
        :bfit => :bfsfit,
        :bfsf => :bfsfit,
        :bfsfit => :bfsfit,
        :bfup => :bfsfup,
        :bfsfup => :bfsfup,
    )
    subs_SFIT = copy(subs_sfit)
    subs_SFIT[:sfit] = sans_style == :upright ? :sfup : (sans_style == :italic ? :sfit : :sfit)
    subs_sfit[:bf] = subs_SFIT[:bfsf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)

    ## `sub_bfsfup`: transformations for bold sans-serif upright glyphs
    subs_bfsfup = Dict(
        ## no-ops:
        :up => :bfsfup,
        :bf => :bfsfup,
        :sf => :bfsfup,
        :bfup => :bfsfup,
        :sfup => :bfsfup,
        :bfsfup => :bfsfup,
        ## other:
        :it => :bfsfit,
        :sfit => :bfsfit,
        :bfsfit => :bfsfit
    )
    subs_BFSFUP = copy(subs_bfsfup)
    subs_BFSFUP[:bfsfup] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)
    
    ## `sub_bfsfit`: transformations for bold sans-serif italic glyphs
    subs_bfsfit = Dict(
        ## no-ops:
        :it => :bfsfit,
        :bf => :bfsfit,
        :sf => :bfsfit,
        :bfit => :bfsfit,
        :sfit => :bfsfit,
        :bfsfit => :bfsfit,
        ## other:
        :up => :bfsfup,
        :sfup => :bfsfup,
        :bfsfup => :bfsfup
    )
    subs_BFSFIT = copy(subs_bfsfit)
    subs_BFSFIT[:bfsfit] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)

    ## other
    subs_tt = Dict(
        :tt => :tt,
        :up => :tt,
    )
    subs_bb = Dict(
        :bb => :bb,
        :up => :bb,
        :it => :bbit
    )
    subs_bbit = Dict(
        :bb => :bbit,
        :it => :bbit,
        :up => :bb
    )

    subs_cal = Dict(
        :cal => :cal,
        :up => :cal,
        :bf => :bfcal,
    )
    subs_frak = Dict(
        :frak => :frak,
        :up => :frak,
        :bf => :bffrak
    )
    subs_bffrak = Dict(
        :frak => :bffrak,
        :up => :bffrak,
        :bf => :bffrak
    )
  
    return Dict(
        :up => subs_up,
        :bfup => subs_bfup,
        :it => subs_it,
        :bfit => subs_bfit,
        :sfup => subs_sfup,
        :bfsfup => subs_bfsfup,
        :sfit => subs_sfit,
        :bfsfit => subs_bfsfit,
        :tt => subs_tt,
        :bb => subs_bb,
        :bbit => subs_bbit,
        :cal => subs_cal,
        :frak => subs_frak,
        :bffrak => subs_bffrak,
        :UP => subs_UP,
        :IT => subs_IT,
        :BFUP => subs_BFUP,
        :BFIT => subs_BFIT,
        :SFUP => subs_SFUP,
        :SFIT => subs_SFIT,
        :BFSFUP => subs_BFSFUP,
        :BFSFIT => subs_BFSFIT,
    )
end