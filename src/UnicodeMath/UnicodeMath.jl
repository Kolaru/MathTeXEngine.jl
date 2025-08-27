module UnicodeMath
#import DataStructures: OrderedDict
#const SpecialDict = OrderedDict
const SpecialDict = Dict

include("extra_commands.jl")  # `extra_commands`

include("character_ranges.jl")  # `chars_by_range_style_name`
                                # `chars_to_ucmchars`

## native styles (excluding derived styles like `bf`, `sf`, `bfsfup`):
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

const all_styles = (base_styles..., :bf, :sf, :bfsf)

## helper function -- given `ucm_ch::UCMChar` and a target style like `:bf`,
## return the corresponding `UCMChar` from the styled alphabet, if it is available for `ucm_ch`.
function _choose_style(ucm_ch, style_symb)
    ## check if the range is key for outer dict:
    chars_by_style_name = get(chars_by_range_style_name, ucm_ch.char_range, nothing)
    isnothing(chars_by_style_name) && return ucm_ch

    ## check if target style is key in 2nd level:
    chars_by_name = get(chars_by_style_name, style_symb, nothing)
    isnothing(chars_by_name) && return ucm_ch

    ## inner dict has `name => UCMChar` entries for target style.
    ## return value if it exists
    ucm_ch = get(chars_by_name, ucm_ch.name, ucm_ch)
    return ucm_ch
end

function _normal_style_mapping(normal_style=:italic)
    @assert normal_style in (:italic, :upright, :literal)
    return Dict(
        :up => normal_style == :italic ? :it : (normal_style == :upright ? :up : :up),
        :it => normal_style == :italic ? :it : (normal_style == :upright ? :up : :it)
    )
end

const aliases_num = Dict(
    :it => :up,
    :bf => :bfup,
    :bfit => :bfup,
    :sf => :sfup,
    :sfit => :sfup,
    :bfsf => :bfsfup,
    :bfsfit => :bfsfup,
    :bbit => :bb    # this is different from LaTeX package
)

function config_dicts(;
    math_style=:tex,
    normal_style=nothing,
    bold_style=nothing,
    sans_style=nothing,
    partial=nothing,
    nabla=nothing
)
    cfg = if math_style == :iso
        (;
            nabla = :upright,
            partial = :italic,
            normal_style = :iso,
            bold_style = :iso,
            sans_style = :italic
        )
    elseif math_style == :tex
        (;
            nabla = :upright,
            partial = :italic,
            normal_style = :tex,
            bold_style = :tex,
            sans_style = :upright
        )
     elseif math_style == :french
        (;
            nabla = :upright,
            partial = :upright,
            normal_style = :french,
            bold_style = :french,
            sans_style = :upright
        )
    elseif math_style == :upright
        (;
            nabla = :upright,
            partial = :upright,
            normal_style = :upright,
            bold_style = :upright,
            sans_style = :upright
        )
   else
        (;
            nabla = :literal,
            partial = :literal,
            normal_style = :literal,
            bold_style = :literal,
            sans_style = :literal
        )
    end
    normal_style = isnothing(normal_style) ? cfg.normal_style : normal_style
    bold_style = isnothing(bold_style) ? cfg.bold_style : bold_style
    sans_style = isnothing(sans_style) ? cfg.sans_style : sans_style
    partial = isnothing(partial) ? cfg.partial : partial
    nabla = isnothing(nabla) ? cfg.nabla : nabla

    normal_styles = preconfigured_normal_styles(normal_style; partial, nabla)
    substitutions = preconfigured_substitutions(bold_style; sans_style, partial, nabla)

    aliases = Dict(
        :num => aliases_num
    )
    
    return normal_styles, substitutions, aliases
end

function preconfigured_normal_styles(
    normal_style_flavor; 
    partial = :literal, nabla = :literal
)
    nt = if normal_style_flavor == :iso
        (;
            Greek = :italic,
            greek = :italic,
            Latin = :italic,
            latin = :italic
        )
    elseif normal_style_flavor == :tex
        (;
            Greek = :upright,
            greek = :italic,
            Latin = :italic,
            latin = :italic
        )
     elseif normal_style_flavor == :french
        (;
            Greek = :upright,
            greek = :upright,
            Latin = :upright,
            latin = :italic
        )
    elseif normal_style_flavor == :upright
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

    ns = Dict(
        :num => _normal_style_mapping(:upright),
        :Greek => _normal_style_mapping(nt.Greek),
        :greek => _normal_style_mapping(nt.greek),
        :Latin => _normal_style_mapping(nt.Latin),
        :latin => _normal_style_mapping(nt.latin),
        :partial => _normal_style_mapping(partial),
        :Nabla => _normal_style_mapping(nabla)
    )
    ns[:dotless] = ns[:latin]
    
    return ns
end

function preconfigured_substitutions(
    bold_style_flavor;
    sans_style = :literal,
    partial = :literal, nabla = :literal
)
    nt = if bold_style_flavor == :iso
        (;
            Greek = :italic,
            greek = :italic,
            Latin = :italic,
            latin = :italic
        )
    elseif bold_style_flavor == :tex
        (;
            Greek = :upright,
            greek = :italic,
            Latin = :upright,
            latin = :upright
        )
    elseif bold_style_flavor == :upright
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

    bs = Dict(
        :num => _subtitutions_dict(; bold_style=:upright, sans_style=:upright),
        :Greek => _subtitutions_dict(; bold_style=nt.Greek, sans_style),
        :greek => _subtitutions_dict(; bold_style=nt.greek, sans_style),
        :Latin => _subtitutions_dict(; bold_style=nt.Latin, sans_style),
        :latin => _subtitutions_dict(; bold_style=nt.latin, sans_style),
        :partial => _subtitutions_dict(; bold_style=partial, sans_style=partial),
        :Nabla => _subtitutions_dict(; bold_style=nabla, sans_style=nabla),
    )
    bs[:dotless] = bs[:latin]
    
    return bs
end

function _subtitutions_dict(;
    bold_style=:literal, 
    sans_style=:italic,
)
    subs_up = Dict( sn => sn for sn = base_styles )
    subs_up[:bf] = bold_style == :upright ? :bfup : (bold_style == :italic ? :bfit : :bfup)
    subs_up[:sf] = sans_style == :upright ? :sfup : (sans_style == :italic ? :sfit : :sfup)
    subs_up[:bfsf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)

    subs_it = Dict( sn => sn for sn = base_styles )
    #subs_it[:bb] = :bbit   # `blackboard_style`?
    subs_it[:bf] = bold_style == :upright ? :bfup : (bold_style == :italic ? :bfit : :bfit)
    subs_it[:sf] = sans_style == :upright ? :sfup : (sans_style == :italic ? :sfit : :sfit)
    subs_it[:bfsf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)

    subs_bfup = Dict(
        :up => :bfup,   # no-op
        :bfup => :bfup, # no-op
        :bf => :bfup,   # no-op
        :it => :bfit,
        :bfit => :bfit,
        :sfup => :bfsfup,
        :bfsfup => :bfsfup,
        :sfit => :bfsfit,
        :bfsfit => :bfsfit,
        :cal => :bfcal,
        :frak => :bffrak
    )
    subs_bfup[:bfsf] = subs_bfup[:sf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)

    subs_bfit = Dict(
        :bf => :bf,     # no-op
        :bfit => :bfit, # no-op
        :it => :bfit,   # no-op
        :up => :bfup,   # undo italization
        :bfup => :bfup, # undo italization
        :sfit => :bfsfit,
        :bfsfit => :bfsfit,
        :sfup => :bfsfup,
        :bfsfup => :bfsfup,
    )
    subs_bfit[:bfsf] = subs_bfit[:sf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)

    subs_sfup = Dict(
        :sf => :sfup,   # no-op
        :sfup => :sfup, # no-op
        :up => :sfup,   # no-op
        :it => :sfit,
        :sfit => :sfit,
        :bfup => :bfsfup,
        :bfsfup => :bfsfup,
        :bfit => :bfsfit,
        :bfsfit => :bfsfit,
    )
    subs_sfup[:bfsf] = subs_sfup[:bf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfup)

    subs_sfit = Dict(
        :sf => :sfit,   # no-op
        :sfit => :sfit, # no-op
        :it => :sfit,   # no-op
        :up => :sfup,
        :sfup => :sfup,
        :bfit => :bfsfit,
        :bfsfit => :bfsfit,
        :bfup => :bfsfup,
        :bfsfup => :bfsfup,
    )
    subs_sfit[:bfsf] = subs_sfit[:bf] = sans_style == :upright ? :bfsfup : (sans_style == :italic ? :bfsfit : :bfsfit)

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
        :bffrak => subs_bffrak
    )
    
end

const (default_normal_styles, default_substitutions, default_aliases) = config_dicts()

const default_normal_styles_ref = Ref(default_normal_styles)
const default_substitutions_ref = Ref(default_substitutions)
const default_aliases_ref = Ref(default_aliases)

function global_config!(; kwargs...)
    global default_normal_styles_ref, default_substitutions_ref, default_aliases_ref
    ns, s, a = config_dicts(; kwargs...)
    default_normal_styles_ref[] = ns
    default_substitutions_ref[] = s
    default_aliases_ref[] = a
    return (; normal_styles=ns, substitutions=s, aliases=a)
end

for fn in (:apply_style, :apply_spec_style)
    @eval function $(fn)(ch::Char, trgt_style::Symbol... ; kwargs...)
        ucm_ch = get(chars_to_ucmchars, ch, nothing)
        isnothing(ucm_ch) && return ch
        ucm_ch = $(fn)(ucm_ch, trgt_style...; kwargs...)
        return ucm_ch.char
    end
end

function sym_style(ch::Union{Char, UCMChar}, trgt_style...)
    global default_normal_styles_ref, default_substitutions_ref, default_aliases_ref

    return apply_style(ch, trgt_style...;
        normal_styles = default_normal_styles_ref[],
        substitutions = default_substitutions_ref[],
        aliases = default_aliases_ref[]
    )
end
sym_style(io::IO, ch::Union{Char, UCMChar}, trgt_style...)=print(io, sym_style(ch, trgt_style...))
function sym_style(io::IO, x::AbstractString, trgt_style...)
    _sym_style = ch -> apply_style(
        ch, trgt_style...;
        normal_styles = default_normal_styles_ref[],
        substitutions = default_substitutions_ref[],
        aliases = default_aliases_ref[]
    )
    for char in x
        print(io, _sym_style(char))
    end
end
sym_style(x::AbstractString, trgt_style...) = sprint() do io
    sym_style(io, x, trgt_style...)
end

for sn in all_styles
    f = Symbol("sym", sn)
    @eval begin 
        $f(ch::Char) = sym_style(ch, $(Meta.quot(sn)))
        $f(x::AbstractString) = sym_style(x, $(Meta.quot(sn)))

        $f(io::IO, x::Char) = sym_style(io, x, $(Meta.quot(sn)))
        $f(io::IO, x::AbstractString) = sym_style(io, x, $(Meta.quot(sn)))
    end
end

function apply_style(
    ucm_ch::UCMChar;
    normal_styles = default_normal_styles,
    kwargs...
)
    if isa(normal_styles, AbstractDict)
        if haskey(normal_styles, ucm_ch.char_range)
            trgt_normal_style = get(normal_styles[ucm_ch.char_range], ucm_ch.style, nothing)
            if !isnothing(trgt_normal_style)
                ucm_ch = _choose_style(ucm_ch, trgt_normal_style)
            end
        end
    end
    return ucm_ch
end

function apply_style(
    ucm_ch::UCMChar, trgt_style::Symbol;
    substitutions = default_substitutions,
    aliases = default_aliases,
    kwargs...
)
    ucm_ch = apply_style(ucm_ch; kwargs...)
    if isa(substitutions, AbstractDict) && haskey(substitutions, ucm_ch.char_range)
        substitutions_range = substitutions[ucm_ch.char_range]
        if haskey(substitutions_range, ucm_ch.style)
            trgt_style = get(substitutions_range[ucm_ch.style], trgt_style, trgt_style)
        end
    end
    if isa(aliases, AbstractDict) && haskey(aliases, ucm_ch.char_range)
        trgt_style = get(aliases[ucm_ch.char_range], trgt_style, trgt_style)
    end
    return _choose_style(ucm_ch, trgt_style)
end

function apply_spec_style(
    ucm_ch::UCMChar, trgt_style::Symbol...;
    math_style=:tex,
    normal_style=nothing,
    bold_style=nothing,
    sans_style=nothing,
    partial=nothing,
    nabla=nothing
)
    normal_styles, substitutions, aliases = config_dicts(; 
        math_style, normal_style, bold_style, sans_style, partial, nabla)
    return apply_style(ucm_ch, trgt_style...; normal_styles, substitutions, aliases)
end

end#module