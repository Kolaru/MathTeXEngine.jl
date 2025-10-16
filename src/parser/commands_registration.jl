struct CanonicalDict{T}
    dict::Dict{T, TeXExpr}
end

CanonicalDict{T}() where T = CanonicalDict(Dict{T, TeXExpr}())

Base.setindex!(d::CanonicalDict, val::TeXExpr, key) = (d.dict[key] = val)
Base.setindex!(d::CanonicalDict{Char}, val::TeXExpr, key::String) = (d[first(key)] = val)

function Base.getindex(d::CanonicalDict, key)
    val = d.dict[key]

    if val isa Char
        return val
    else
        return copy(val)
    end
end

Base.getindex(d::CanonicalDict{Char}, key::String) = d[first(key)]

Base.haskey(d::CanonicalDict, key) = haskey(d.dict, key)
Base.haskey(d::CanonicalDict{Char}, key::String) = haskey(d, first(key))

function Base.get(d::CanonicalDict, key, default)
    haskey(d, key) && return d[key]
    return default
end

# Each symbol or com_str has a unique canonical representation
const symbol_to_canonical = CanonicalDict{Char}()

function canonical_expr(char::Char)
    haskey(symbol_to_canonical, char) && return symbol_to_canonical[char]
    return TeXExpr(:char, char)
end

function get_symbol_char(com_str)
    if !haskey(latex_symbols, com_str)
        @warn "unknown command string $com_str"
        return '?'
    end

    return first(latex_symbols[com_str])
end

##
## Commands
##

function command_expr(com_str, args)
    template = copy(command_definitions[com_str][1])
    return TeXExpr(template.head, vcat(template.args, args))
end
required_args(com_str) = command_definitions[com_str][2]

const command_definitions = Dict(
    raw"\frac" => (TeXExpr(:frac), 2),
    raw"\sqrt" => (TeXExpr(:sqrt), 1),
    raw"\overline" => (TeXExpr(:overline), 1),
    raw"\{" => (TeXExpr(:delimiter, '{'), 0),
    raw"\}" => (TeXExpr(:delimiter, '}'), 0),
    raw"\_" => (TeXExpr(:symbol, '_'), 0),
    raw"\%" => (TeXExpr(:symbol, '%'), 0),
    raw"\$" => (TeXExpr(:symbol, '$'), 0),
    raw"\#" => (TeXExpr(:symbol, '#'), 0),
    raw"\&" => (TeXExpr(:symbol, '&'), 0),
    raw"\fontfamily" => (TeXExpr(:fontfamily), 1),
    raw"\glyph" => (TeXExpr(:glyph), 2),
    raw"\unicode" => (TeXExpr(:unicode), 2),
)

for func in underover_functions
    com_str = "\\" * func
    template = TeXExpr(:underover, Any[TeXExpr(:function, func), nothing, nothing])
    command_definitions[com_str] = (template, 0)
end

for func in generic_functions
    com_str = "\\" * func
    command_definitions[com_str] = (TeXExpr(:function, func), 0)
end

for (com_str, width) in space_commands
    command_definitions[com_str] = (TeXExpr(:space, width), 0)
end

for com_str in combining_accents
    combining_char = get_symbol_char(com_str)
    template = TeXExpr(:combining_accent, TeXExpr(:symbol, combining_char))
    command_definitions[com_str] = (template, 1)
end

for name in font_names
    com_str = "\\math$name"
    command_definitions[com_str] = (TeXExpr(:font, Symbol(name)), 1)
    com_str = "\\text$name"
    command_definitions[com_str] = (TeXExpr(:text, Symbol(name)), 1)
end
command_definitions["\\text"] = (TeXExpr(:text, :rm), 1)

##
## Symbols
##

# Symbols missing from the REPL completion data
latex_symbols[raw"\neq"] = "≠"
latex_symbols[raw"\upepsilon"] = "ε"

# Numbers
for char in join(0:9)
    symbol_to_canonical[char] = TeXExpr(:digit, char)
end

for symbol in spaced_symbols
    symbol_expr = TeXExpr(:symbol, symbol)
    symbol_to_canonical[symbol] = TeXExpr(:spaced, symbol_expr)
end

for com_str in spaced_commands
    symbol = get_symbol_char(com_str)
    symbol_expr = TeXExpr(:symbol, symbol)
    template = TeXExpr(:spaced, symbol_expr)
    symbol_to_canonical[symbol] = template
    command_definitions[com_str] = (template, 0)
end

for com_str in underover_commands
    symbol = get_symbol_char(com_str)
    symbol_expr = TeXExpr(:symbol, symbol)
    template = TeXExpr(:underover, Any[symbol_expr, nothing, nothing])
    symbol_to_canonical[symbol] = template
    command_definitions[com_str] = (template, 0)
end

for com_str in integral_commands
    symbol = get_symbol_char(com_str)
    symbol_expr = TeXExpr(:symbol, symbol)
    template = TeXExpr(:integral, Any[symbol_expr, nothing, nothing])
    symbol_to_canonical[symbol] = template
    command_definitions[com_str] = (template, 0)
end

for (symbol, width) in space_symbols
    symbol_to_canonical[symbol] = TeXExpr(:space, width)
end

for symbol in punctuation_symbols
    symbol = first(symbol)
    symbol_to_canonical[symbol] = TeXExpr(:punctuation, symbol)
end

for symbol in delimiter_symbols
    symbol = first(symbol)
    symbol_to_canonical[symbol] = TeXExpr(:delimiter, symbol)
end

##
## Default behavior
##
# We put it at the end to avoid overwritting existing commands

for (com_str, symbol) in latex_symbols
    symbol = first(symbol)  # Convert String to Char
    symbol_expr = TeXExpr(:symbol, symbol)

    if !haskey(symbol_to_canonical, symbol)
        symbol_to_canonical[symbol] = symbol_expr
    end

    # Separate case for symbols that have multiple valid commands
    if !haskey(command_definitions, com_str)
        command_definitions[com_str] = (symbol_expr, 0)
    end
end
