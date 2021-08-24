struct LayoutState
    font_family::FontFamily
    font_modifiers::Vector{Symbol}
end

LayoutState(font_family::FontFamily) = LayoutState(font_family, Symbol[])
LayoutState() = LayoutState(FontFamily())

Base.broadcastable(state::LayoutState) = [state]

function add_font_modifier(state::LayoutState, modifier)
    modifiers = [state.font_modifiers..., modifier]
    return LayoutState(state.font_family, modifiers)
end

function get_font(state::LayoutState, char_type)
    font_family = state.font_family
    font_id = font_family.font_mapping[char_type]

    for modifier in state.font_modifiers
        if haskey(font_family.font_modifiers, modifier)
            mapping = font_family.font_modifiers[modifier]
            font_id = get(mapping, font_id, font_id)
        else
            throw(ArgumentError("font modifier $modifier not supported for the current font family."))
        end
    end

    return get_font(font_family, font_id)
end