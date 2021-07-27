struct CanonicalDict{T}
    dict::Dict{T, Union{Char, TeXExpr}}
end

CanonicalDict{T}() where T = CanonicalDict(Dict{T, Union{Char, TeXExpr}}())

Base.setindex!(d::CanonicalDict, val, key) = (d.dict[key] = val)
Base.setindex!(d::CanonicalDict, val::String, key) = (d.dict[key] = first(val))
Base.setindex!(d::CanonicalDict{Char}, val::String, key::String) = (d[first(key)] = first(val))
Base.setindex!(d::CanonicalDict{Char}, val, key::String) = (d[first(key)] = val)

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

Base.get(d::CanonicalDict, key, default) = get(d.dict, key, default)

# Each symbol or command has a unique canonical representation, either
# as a unicode Char for symbol, or as a TeXExpr for more complicated cases
const symbol_to_canonical = CanonicalDict{Char}()
const command_to_canonical = CanonicalDict{String}()

# Symbols missing from the REPL completion data
latex_symbols[raw"\neq"] = "≠"

function get_symbol_char(command)
    if !haskey(latex_symbols, command)
        @warn "unkown command $command"
        return '?'
    end

    return first(latex_symbols[command])
end

# Default behavior
for (command, symbol) in latex_symbols
    symbol_to_canonical[symbol] = symbol
    command_to_canonical[command] = symbol
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
    symbol_to_canonical[symbol] = TeXExpr(:spaced, Char[symbol])
end

# Special case for hyphen that must be replaced by a minus sign
symbol_to_canonical['-'] = TeXExpr(:spaced, ['−'])

for command in spaced_commands
    symbol = get_symbol_char(command)
    symbol_to_canonical[symbol] = command_to_canonical[command] = TeXExpr(:spaced, Char[symbol])
end

for command in underover_commands
    symbol = get_symbol_char(command)
    symbol_to_canonical[symbol] = command_to_canonical[command] = TeXExpr(:underover, Any[symbol, nothing, nothing])
end

for func in underover_functions
    command = "\\" * func
    command_to_canonical[command] = TeXExpr(:underover, Any[TeXExpr(:function, [func]), nothing, nothing])
end

for command in integral_commands
    symbol = get_symbol_char(command)
    symbol_to_canonical[symbol] = command_to_canonical[command] = TeXExpr(:integral, Any[symbol, nothing, nothing])
end

for func in generic_functions
    command = "\\" * func
    command_to_canonical[command] = TeXExpr(:function, [func])
end

for (command, width) in space_commands
    command_to_canonical[command] = TeXExpr(:space, [width])
end

for (symbol, width) in space_symbols
    symbol_to_canonical[symbol] = TeXExpr(:space, [width])
end
