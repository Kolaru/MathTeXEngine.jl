_latex_to_new_computer_modern = Dict(
    raw"\int" => 5930,
    raw"\sum" => 5941,

    raw"\partial" => 3377,
    raw"\varepsilon" => 3356,
    raw"\vartheta" => 3379,
    raw"\varkappa" => 3380,
    raw"\varphi" => 3373,
    raw"\varrho" => 3382,
    raw"\varpi" => 3383,

    raw"\epsilon" => 3378,
    raw"\theta" => 3359,
    raw"\kappa" => 3361,
    raw"\phi" => 3381,
    raw"\rho" => 3368,
    raw"\pi" => 3367
)


_symbol_to_new_computer_modern = Dict{Char, Tuple{String, Int}}()
cmmath_fontpath = joinpath("NewComputerModern", "NewCMMath-Regular.otf")

for (symbol,  glyph_id) in _latex_to_new_computer_modern
    if haskey(latex_symbols, symbol)
        symbol = latex_symbols[symbol][1]
    else
        symbol = symbol[1]
    end
    
    _symbol_to_new_computer_modern[symbol] = (cmmath_fontpath, glyph_id)
end

# Standard lowercase greek symbols : thin and italic
for i in 0:24
    small = 'α' + i

    if !haskey(_symbol_to_new_computer_modern, small)
        _symbol_to_new_computer_modern[small] = (cmmath_fontpath, 3352 + i)
    end
end

# Special case : get hbar from the italic font
_symbol_to_new_computer_modern['ħ'] = (
    joinpath("NewComputerModern", "NewCM10-Italic.otf"),
    231
)