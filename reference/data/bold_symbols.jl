function bold_symbol_char_groups(; group_size = 12)
    font_family = FontFamily()
    bold_font = MathTeXEngine.get_font(font_family, :bold)
    special_chars = sort(collect(keys(font_family.special_chars)))

    bold_chars = [
        char for char in special_chars
            if MathTeXEngine.glyph_index(bold_font, char) != 0
    ]
    fallback_chars = [
        char for char in special_chars
            if MathTeXEngine.glyph_index(bold_font, char) == 0
    ]

    return Iterators.partition(bold_chars, group_size),
        Iterators.partition(fallback_chars, group_size)
end

function bold_symbol_rows()
    bold_groups, fallback_groups = bold_symbol_char_groups()

    rows = String[]
    for group in bold_groups
        symbols = join(group)
        push!(rows, "\\mathbf{$symbols}")
        push!(rows, "\\boldsymbol{$symbols}")
        push!(rows, "\\bm{$symbols}")
    end

    for group in fallback_groups
        symbols = join(group)
        push!(rows, "\\boldsymbol{$symbols}")
    end

    return rows
end

const BOLD_SYMBOLS = bold_symbol_rows()
