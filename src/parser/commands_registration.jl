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


# Each symbol or command has a unique canonical representation
const symbol_to_canonical = CanonicalDict{Char}()
const command_to_canonical = CanonicalDict{String}()

function canonical_expr(char::Char)
    haskey(symbol_to_canonical, char) && return symbol_to_canonical[char]
    return TeXExpr(:char, char)
end

canonical_expr(command::String) = get(command_to_canonical, command, nothing)

# Symbols missing from the REPL completion data
latex_symbols[raw"\neq"] = "≠"

function get_symbol_char(command)
    if !haskey(latex_symbols, command)
        @warn "unknown command $command"
        return '?'
    end

    return first(latex_symbols[command])
end

# Numbers
for char in join(0:9)
    symbol_to_canonical[char] = TeXExpr(:digit, char)
end

##
## Special commands
##

command_to_canonical[raw"\frac"] = TeXExpr(:argument_gatherer, [:frac, 2])
command_to_canonical[raw"\sqrt"] = TeXExpr(:argument_gatherer, [:sqrt, 1])

##
## Commands from the commands_data.jl file
##

for symbol in spaced_symbols
    symbol_expr = TeXExpr(:symbol, symbol)
    symbol_to_canonical[symbol] = TeXExpr(:spaced, symbol_expr)
end

# Special case for hyphen that must be replaced by a minus sign
# TODO Make sure it is not replaced outside of math mode
symbol_to_canonical['-'] = TeXExpr(:spaced, TeXExpr(:symbol, '−'))

for command in spaced_commands
    symbol = get_symbol_char(command)
    symbol_expr = TeXExpr(:symbol, symbol)
    symbol_to_canonical[symbol] = command_to_canonical[command] = TeXExpr(:spaced, symbol_expr)
end

for command in underover_commands
    symbol = get_symbol_char(command)
    symbol_expr = TeXExpr(:symbol, symbol)
    symbol_to_canonical[symbol] = command_to_canonical[command] = TeXExpr(:underover, Any[symbol_expr, nothing, nothing])
end

for func in underover_functions
    command = "\\" * func
    command_to_canonical[command] = TeXExpr(:underover, Any[TeXExpr(:function, func), nothing, nothing])
end

for command in integral_commands
    symbol = get_symbol_char(command)
    symbol_expr = TeXExpr(:symbol, symbol)
    symbol_to_canonical[symbol] = command_to_canonical[command] = TeXExpr(:integral, Any[symbol_expr, nothing, nothing])
end

for func in generic_functions
    command = "\\" * func
    command_to_canonical[command] = TeXExpr(:function, func)
end

for (command, width) in space_commands
    command_to_canonical[command] = TeXExpr(:space, width)
end

for (symbol, width) in space_symbols
    symbol_to_canonical[symbol] = TeXExpr(:space, width)
end

for command in combining_accents
    combining_char = get_symbol_char(command)
    symbol_expr = TeXExpr(:symbol, combining_char)
    command_to_canonical[command] = TeXExpr(:argument_gatherer, [:combining_accent, 2, symbol_expr])
end

for symbol in punctuation_symbols
    symbol = first(symbol)
    symbol_to_canonical[symbol] = TeXExpr(:punctuation, symbol)
end

for symbol in delimiter_symbols
    symbol = first(symbol)
    symbol_to_canonical[symbol] = TeXExpr(:delimiter, symbol)
end

for name in font_names
    command = "\\math$name"
    command_to_canonical[command] = TeXExpr(:argument_gatherer, [:font, 2, Symbol(name)])
    command = "\\text$name"
    command_to_canonical[command] = TeXExpr(:argument_gatherer, [:text, 2, Symbol(name)])
end
command = "\\text"
command_to_canonical[command] = TeXExpr(:argument_gatherer, [:text, 2, :rm])

##
## Default behavior
##
# We put it at the end to avoid overwritting existing commands

for (command, symbol) in latex_symbols
    symbol = first(symbol)  # Convert String to Char
    symbol_expr = TeXExpr(:symbol, [symbol])
    
    if !haskey(symbol_to_canonical, symbol)
        symbol_to_canonical[symbol] = symbol_expr
    end

    # Separate case for symbols that have multiple valid commands
    if !haskey(command_to_canonical, command)
        command_to_canonical[command] = symbol_expr
    end
end
