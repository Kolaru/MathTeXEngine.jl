# TODO Add greek letter to have the proper italic ones
_latex_to_new_computer_modern = Dict(
    raw"\int" => ("NewCMMath-Regular", 5930)
)


_symbol_to_new_computer_modern = Dict{Char, Tuple{String, Int}}()

for (symbol, (fontname, glyph_id)) in _latex_to_new_computer_modern
    if haskey(latex_symbols, symbol)
        symbol = latex_symbols[symbol][1]
    else
        symbol = symbol[1]
    end
    
    fontpath = joinpath("NewComputerModern", "$fontname.otf")
    _symbol_to_new_computer_modern[symbol] = (fontpath, glyph_id)
end
