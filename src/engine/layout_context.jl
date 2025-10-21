struct LayoutState
    font_family::FontFamily
    font_modifiers::Vector{Symbol}
    ucm_modifiers::Vector{Symbol}
    tex_mode::Symbol
end

LayoutState(font_family::FontFamily, modifiers::Vector) = LayoutState(font_family, modifiers, Symbol[], :text)
LayoutState(font_family::FontFamily) = LayoutState(font_family, Symbol[])
LayoutState() = LayoutState(FontFamily())

function Base.show(io::IO, state::LayoutState)
    print(io, "LayoutState($(state.font_modifiers), $(state.tex_mode))")
end

Base.broadcastable(state::LayoutState) = Ref(state)

function change_mode(state::LayoutState, mode)
    LayoutState(state.font_family, state.font_modifiers, state.ucm_modifiers, mode)
end

function add_font_modifier(state::LayoutState, modifier)
    modifiers = vcat(state.font_modifiers, modifier)
    return LayoutState(state.font_family, modifiers, state.ucm_modifiers, state.tex_mode)
end

function add_ucm_modifier(state::LayoutState, modifier)
    modifiers = vcat(state.ucm_modifiers, modifier)
    return LayoutState(state.font_family, state.font_modifiers, modifiers, state.tex_mode)
end

function get_font(state::LayoutState, char_type)
    font_family = state.font_family
    font_id = get_font_id(state, char_type)
    return get_font(font_family, font_id)
end

function get_font_id(state::LayoutState, char_type)
    if state.tex_mode == :text
        char_type = :text
    end

    font_family = state.font_family
    font_id = get(font_family.font_mapping, char_type, :math)

    if font_id != :math
        for modifier in state.font_modifiers    # TODO should we use `reverse` here?
            if haskey(font_family.font_modifiers, modifier)
                mapping = font_family.font_modifiers[modifier]
                font_id = get(mapping, font_id, font_id)
            else
                throw(ArgumentError("font modifier $modifier not supported for the current font family."))
            end
        end
    end
    return font_id
end