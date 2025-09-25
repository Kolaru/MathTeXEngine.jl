struct LayoutState
    font_family::FontFamily
    font_modifiers::Vector{Symbol}
    tex_mode::Symbol
end

LayoutState(font_family::FontFamily, modifiers::Vector) = LayoutState(font_family, modifiers, :text)
LayoutState(font_family::FontFamily) = LayoutState(font_family, Symbol[])
LayoutState() = LayoutState(FontFamily())

function Base.show(io::IO, state::LayoutState)
    print(io, "LayoutState($(state.font_modifiers), $(state.tex_mode))")
end

Base.broadcastable(state::LayoutState) = Ref(state)

function change_mode(state::LayoutState, mode)
    LayoutState(state.font_family, state.font_modifiers, mode)
end

function add_font_modifier(state::LayoutState, modifier)
    modifiers = vcat(state.font_modifiers, modifier)
    return LayoutState(state.font_family, modifiers, state.tex_mode)
end

function get_font(state::LayoutState, char_type)
    if state.tex_mode == :text
        char_type = :text
    end

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