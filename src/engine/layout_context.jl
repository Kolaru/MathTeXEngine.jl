struct LayoutState
    fontset::FontSet
    font_modifiers::Vector{Symbol}
end

LayoutState(fontset::FontSet) = LayoutState(fontset, Symbol[])
LayoutState() = LayoutState(FontSet())

Base.broadcastable(state::LayoutState) = [state]

function add_font_modifier(state::LayoutState, modifier)
    modifiers = [state.font_modifiers..., modifier]
    return LayoutState(state.fontset, modifiers)
end

function get_font(state::LayoutState, char_type)
    fontset = state.fontset
    font_id = fontset.font_mapping[char_type]

    for modifier in state.font_modifiers
        if haskey(fontset.font_modifiers, modifier)
            mapping = fontset.font_modifiers[modifier]
            font_id = get(mapping, font_id, font_id)
        else
            throw(ArgumentError("font modifier $modifier not supported for the current fontset."))
        end
    end

    return fontset[font_id]
end