"""
Return the y value needed for the element to be vertically centered in the
middle of the xheight.
"""
function y_for_centered(font_family, elem)
    h = inkheight(elem)
    return h / 2 + xheight(font_family) / 2
end

function argument_as_string(arg)
    return String(Char.(arg.args))
end

const _TEXT_OPERATOR_SPACE = 0.2
const _SCRIPT_OPERATOR_SPACE = 0.08
const _MIN_SCRIPT_GAP = 0.04
const _TALL_SCRIPT_CORE_HEIGHT = 1.2
const _TALL_SCRIPT_VERTICAL_CLEARANCE = 0.65
const _TALL_SCRIPT_CORE_OVERLAP = 0.3
const _FRACTION_RULE_PADDING = 0.65
const _SCRIPT_FRACTION_RULE_WIDTH = 0.45
const _SCRIPT_FRACTION_RULE_SHIFT = 0.18
const _TALL_SCRIPT_HEIGHT_FACTOR = 1.5
const _SCRIPT_SHRINK_HEIGHT_FACTOR = 1.5
const _SQRT_TALL_CONTENT_CLEARANCE_FACTOR = 0.25
const _SQRT_RULE_CONTENT_DESCENT = 0.9
const _SQRT_RULE_PADDING = 0.12
const _SLANTED_ADJACENT_GAP = 0.03
const _DISPLAY_OPERATOR_DELIMITER_HEIGHT = 1.35
const _BRACE_RULE_AXIS_PADDING = 0.2

function _script_y_positions(core, sub, super, font_family, sub_shrink, super_shrink)
    xh = xheight(font_family)
    script_gap = max(thickness(font_family), _MIN_SCRIPT_GAP)
    tall_script_height = _TALL_SCRIPT_HEIGHT_FACTOR * xh

    sub_y = -0.2
    if _has_rule_element(sub) || inkheight(sub) * sub_shrink > tall_script_height
        sub_y = min(sub_y, -topinkbound(sub) * sub_shrink - script_gap)
    end

    super_y = xh
    if _has_rule_element(super) || inkheight(super) * super_shrink > tall_script_height
        super_y = max(super_y, -bottominkbound(super) * super_shrink + xh + script_gap)
    end
    super_y -= max(bottominkbound(super), 0) * super_shrink

    if inkheight(core) > _TALL_SCRIPT_CORE_HEIGHT
        sub_top = bottominkbound(core) + _TALL_SCRIPT_VERTICAL_CLEARANCE * xh
        super_bottom = topinkbound(core) - _TALL_SCRIPT_VERTICAL_CLEARANCE * xh
        sub_y = min(sub_y, sub_top - topinkbound(sub) * sub_shrink)
        super_y = max(super_y, super_bottom - bottominkbound(super) * super_shrink)
    end

    return sub_y, super_y
end

function _script_shrink(elem, font_family, shrink)
    is_tall_script =
        _has_rule_element(elem) ||
        inkheight(elem) * shrink > _SCRIPT_SHRINK_HEIGHT_FACTOR * xheight(font_family)
    return is_tall_script ? 0.5 : shrink
end

function _subscript_x_position(core, font_family, tall_core)
    script_edge = is_slanted(core) ? hadvance(core) : max(hadvance(core), rightinkbound(core))
    if tall_core
        script_edge -= _TALL_SCRIPT_CORE_OVERLAP * xheight(font_family)
    end

    return script_edge
end

function _superscript_x_position(core, font_family, tall_core)
    script_edge = max(hadvance(core), rightinkbound(core))
    if tall_core
        script_edge -= _TALL_SCRIPT_CORE_OVERLAP * xheight(font_family)
    end

    return script_edge
end

function _fraction_rule_width(argument_width, font_family, script_level)
    if script_level > 0
        return _SCRIPT_FRACTION_RULE_WIDTH * argument_width
    end

    return argument_width + _FRACTION_RULE_PADDING * xheight(font_family)
end

function _has_rule_element(elem)
    elem isa Union{HLine, VLine} && return true
    if elem isa Group
        return any(_has_rule_element, elem.elements)
    end

    return false
end

function _sqrt_radical(state, target_height)
    font_family = state.font_family
    radicals = TeXElement[TeXChar('√', state, :symbol)]

    for radical_name in ("radical.v1", "radical.v2", "radical.v3", "radical.v4")
        candidate = TeXChar(radical_name, state, :symbol; represented = '√')
        candidate.glyph_id != 0 && push!(radicals, candidate)

        fallback = default_math_texchar(radical_name, font_family, '√')
        isnothing(fallback) || push!(radicals, fallback)
    end

    sort!(radicals; by = inkheight)
    for candidate in radicals
        if candidate.glyph_id == 0
            continue
        end
        inkheight(candidate) >= target_height && return candidate
    end

    return last(radicals)
end

const _math_delimiter_chars = Set(['(', ')', '[', ']', '{', '}', '⟨', '⟩', '|', '‖'])
const _display_operator_chars = Set(['∫', '∑', '∏'])
const _delimiter_axis_operator_chars =
    Set(['+', '-', '−', '±', '∓', '×', '⋅', '=', '<', '>', '≤', '≥', '≠'])

function _delimiter_element(char, state)
    font_family = state.font_family

    if char in _math_delimiter_chars
        texchar = default_math_texchar(char, font_family, char)
        if !isnothing(texchar)
            return texchar
        end
    end

    return TeXChar(char, state, :delimiter)
end

function _is_brace_delimiter(delimiter)
    return delimiter isa TeXChar && delimiter.represented_char in ('{', '}')
end

function _delimiter_target_height(content, content_axis, delimiter, font_family)
    n_visible, elem = _count_visible_nondelimiters(content)
    if n_visible == 1
        if elem isa TeXChar && elem.represented_char in _display_operator_chars
            return min(inkheight(content), _DISPLAY_OPERATOR_DELIMITER_HEIGHT)
        end
    end

    height = inkheight(content)
    if _has_rule_element(content)
        axis_height = 2max(
            content_axis - bottominkbound(content),
            topinkbound(content) - content_axis,
        )
        if _is_brace_delimiter(delimiter)
            axis_height = min(
                axis_height,
                height + _BRACE_RULE_AXIS_PADDING * xheight(font_family),
            )
        end
        return max(height, axis_height)
    end

    return height
end

function _count_visible_nondelimiters(elem)
    elem isa Space && return 0, nothing

    if elem isa Group
        n_visible = 0
        only_visible = nothing
        for child in elem.elements
            n_child, child_visible = _count_visible_nondelimiters(child)
            n_visible += n_child
            if n_child == 1
                only_visible = child_visible
            end
            n_visible > 1 && return n_visible, nothing
        end
        return n_visible, only_visible
    end

    if elem isa TeXChar && elem.represented_char in _math_delimiter_chars
        return 0, nothing
    end

    return 1, elem
end

function _delimiter_visual_bounds(elem)
    elem isa Space && return nothing
    elem isa Union{HLine, VLine} && return nothing

    if elem isa TeXChar
        elem.represented_char in _math_delimiter_chars && return nothing
        elem.represented_char in _delimiter_axis_operator_chars && return nothing
        return bottominkbound(elem), topinkbound(elem)
    end

    if elem isa Group
        bottom = Inf
        top = -Inf
        for (child, position, scale) in zip(elem.elements, elem.positions, elem.scales)
            child_bounds = _delimiter_visual_bounds(child)
            isnothing(child_bounds) && continue

            child_bottom, child_top = child_bounds
            bottom = min(bottom, position[2] + scale * child_bottom)
            top = max(top, position[2] + scale * child_top)
        end

        isinf(bottom) && return nothing
        return bottom, top
    end

    return bottominkbound(elem), topinkbound(elem)
end

function _delimiter_axis(content, font_family)
    axis = max(vmid(content), xheight(font_family) / 2)
    _has_rule_element(content) && return axis

    bounds = _delimiter_visual_bounds(content)
    isnothing(bounds) && return axis

    visual_axis = (bounds[1] + bounds[2]) / 2
    return max(axis, visual_axis)
end

function _sqrt_clearance(content, font_family)
    xh = xheight(font_family)
    clearance = _has_rule_element(content) ? xh / 3 : xh / 2
    return max(thickness(font_family), clearance)
end

function _sqrt_radical_extra_height(content, font_family)
    _has_rule_element(content) || return 0.0
    return _SQRT_TALL_CONTENT_CLEARANCE_FACTOR * xheight(font_family)
end

"""
    tex_layout(mathexpr::TeXExpr, font_family)

Recursively determine the layout of the math expression represented the given
TeXExpr for the given font set.

Return a set of nested objects, positioned and scaled relative to their parent.
"""
tex_layout(expr, font_family::FontFamily) = tex_layout(expr, LayoutState(font_family))

function tex_layout(expr, state)
    font_family = state.font_family
    head = expr.head
    args = [expr.args...]
    shrink = 0.6
    italic_correction = state.tex_mode == :inline_math && italic_correction_enabled[]

    try
        if isleaf(expr)  # :char, :delimiter, :digit, :punctuation, :symbol
            char = args[1]
            if char == ' ' && state.tex_mode == :inline_math
                return Space(0.0)
            elseif head == :delimiter
                return _delimiter_element(char, state)
            end
            return TeXChar(char, state, head)
        elseif head == :combining_accent
            accent, core = tex_layout.(args, state)

            # Same space between the top of core and the accent than
            # between the top of a 'x' and the accent
            y = topinkbound(core) - xheight(font_family)

            if core.slanted
                α = slant_angle(font_family)
                x = (y + bottominkbound(accent)) * tan(α) / 2
            else
                x = 0.0
            end

            return Group(
                [core, accent],
                Point2f[(0, 0), (x + hmid(core) - hmid(accent), y)],
                [1, 1];
                slanted = is_slanted(core),
            )
        elseif head == :decorated
            core = tex_layout(args[1], state)
            script_state = increase_script_level(state)
            sub = tex_layout(args[2], script_state)
            super = tex_layout(args[3], script_state)

            sub_shrink = _script_shrink(sub, font_family, shrink)
            super_shrink = _script_shrink(super, font_family, shrink)
            tall_core = inkheight(core) > _TALL_SCRIPT_CORE_HEIGHT
            sub_y, super_y = _script_y_positions(
                core,
                sub,
                super,
                font_family,
                sub_shrink,
                super_shrink,
            )
            if !isnothing(args[3]) && args[3].head == :primes
                super_x = min(hadvance(core), rightinkbound(core)) - 0.1
                super_y = 0.1
                super_shrink = 1
            else
                super_x = _superscript_x_position(
                    core,
                    font_family,
                    tall_core,
                )
            end
            sub_x = _subscript_x_position(
                core,
                font_family,
                tall_core,
            )

            return Group(
                [core, sub, super],
                Point2f[
                    (0, 0),
                    (sub_x, sub_y),
                    (super_x, super_y),
                ],
                [1, sub_shrink, super_shrink];
                slanted = is_slanted(core) || is_slanted(super),
            )
        elseif head == :delimited
            elements = tex_layout.(args, state)
            left, content, right = elements

            content_midline = _delimiter_axis(content, font_family)
            left_height = _delimiter_target_height(content, content_midline, left, font_family)
            right_height = _delimiter_target_height(content, content_midline, right, font_family)
            left_scale = max(1, left_height / inkheight(left))
            right_scale = max(1, right_height / inkheight(right))
            scales = [left_scale, 1, right_scale]

            dxs = hadvance.(elements) .* scales
            xs = [0, cumsum(dxs[1:(end - 1)])...]

            return Group(
                elements,
                Point2f[
                    (xs[1], content_midline - vmid(left) * left_scale),
                    (xs[2], 0),
                    (xs[3], content_midline - vmid(right) * right_scale),
                ],
                scales;
                slanted = is_slanted(right),
            )
        elseif head == :font
            modifier, content = args
            return tex_layout(content, add_font_modifier(state, modifier))
        elseif head == :boldsymbol
            content = only(args)
            return tex_layout(content, add_font_modifier(state, :bf))
        elseif head == :fontfamily
            return Space(0)
        elseif head == :frac
            numerator = tex_layout(args[1], state)
            denominator = tex_layout(args[2], state)

            xh = xheight(font_family)
            argument_left = min(leftinkbound(numerator), leftinkbound(denominator))
            argument_right = max(rightinkbound(numerator), rightinkbound(denominator))
            argument_width = argument_right - argument_left
            rule_width = _fraction_rule_width(argument_width, font_family, state.script_level)

            # fixed width fraction line
            rule_thickness = thickness(font_family)

            line = HLine(rule_width, rule_thickness)
            y0 = xh / 2 - rule_thickness / 2

            # Align the rule and arguments around the same center. This matters
            # for shortened script-style rules, where anchoring at x = 0 makes
            # the rule look too long on one side.
            center = (argument_left + argument_right) / 2
            xline = center - hmid(line)
            if state.script_level > 0
                xline -= _SCRIPT_FRACTION_RULE_SHIFT * argument_width
            end
            x1 = center - hmid(numerator)
            x2 = center - hmid(denominator)

            ytop = y0 + xh / 2 - bottominkbound(numerator)
            ybottom = y0 - xh / 2 - topinkbound(denominator)

            return Group(
                [line, numerator, denominator],
                Point2f[(xline, y0), (x1, ytop), (x2, ybottom)];
                slanted = is_slanted(numerator) || is_slanted(denominator),
            )
        elseif head == :function
            name = args[1]
            elements = TeXChar.(collect(name), state, Ref(:function))
            return horizontal_layout(elements; italic_correction)
        elseif head == :glyph
            font_id, glyph_id = argument_as_string.(args)
            font_id = Symbol(font_id)
            glyph_id = parse(Culong, glyph_id)
            font = get_font(state.font_family, font_id)
            return TeXChar(glyph_id, font, state.font_family, false, '?')
        elseif head in (:group, :inline_math, :line)
            mode = (head == :inline_math) ? :inline_math : state.tex_mode
            child_state = change_mode(state, mode)
            elements = tex_layout.(args, child_state)
            if isempty(elements)
                return Space(0.0)
            end

            if mode == :inline_math
                elements = _add_math_operator_spacing(args, elements)
            end

            italic_correction = mode == :inline_math && italic_correction_enabled[]
            return horizontal_layout(elements; italic_correction)
        elseif head == :integral
            pad = 0.1
            int, sub, super = tex_layout.(args, state)

            return Group(
                [int, sub, super],
                Point2f[
                    (0, 0),
                    (
                        0.15 - inkwidth(sub) * shrink / 2,
                        bottominkbound(int) - topinkbound(sub) * shrink - pad,
                    ),
                    (0.85 - inkwidth(super) * shrink / 2, topinkbound(int) + pad),
                ],
                [1, shrink, shrink];
                slanted = is_slanted(int),
            )
        elseif head == :lines
            length(args) == 1 && return tex_layout(only(args), state)
            lineheight = 1.3
            lines = tex_layout.(args, state)
            points = map(enumerate(lines)) do (k, line)
                x = -inkwidth(line) / 2
                y = (1 - k) * lineheight
                return Point2f(x, y)
            end

            return Group(lines, points)
        elseif head == :overline
            content = tex_layout(args[1], state)

            lw = thickness(font_family)
            y = topinkbound(content) - lw

            hline = HLine(inkwidth(content) - 0.15, lw)

            return Group(
                [hline, content],
                Point2f[(0.25, y + lw / 2 + 0.2), (0, 0)];
                slanted = is_slanted(content),
            )
        elseif head == :primes
            primes = [TeXExpr(:char, ''') for _ in 1:only(args)]
            return horizontal_layout(tex_layout.(primes, state); italic_correction)
        elseif head == :space
            return Space(args[1])
        elseif head == :spaced
            sym = tex_layout(args[1], state)
            space = state.script_level > 0 ? _SCRIPT_OPERATOR_SPACE : _TEXT_OPERATOR_SPACE
            return horizontal_layout([Space(space), sym, Space(space)]; italic_correction)
        elseif head == :sqrt
            content = tex_layout(args[1], state)
            rule_thickness = thickness(font_family)
            xh = xheight(font_family)
            clearance = _sqrt_clearance(content, font_family)
            radical_clearance = _sqrt_radical_extra_height(content, font_family)
            target_height = inkheight(content) + radical_clearance
            radical = _sqrt_radical(state, target_height)

            line_top = topinkbound(content) + clearance
            if _has_rule_element(content)
                radical_bottom = bottominkbound(content) - _SQRT_RULE_CONTENT_DESCENT * xh
                line_top = max(line_top, radical_bottom + inkheight(radical))
            end
            y0 = line_top - topinkbound(radical)
            line_y = line_top - rule_thickness / 2

            hline_width =
                max(rightinkbound(content), xheight(font_family) / 2) +
                _SQRT_RULE_PADDING * xh +
                rule_thickness
            hline = HLine(hline_width, rule_thickness)
            hline_x = rightinkbound(radical) - rule_thickness / 2

            return Group(
                [radical, hline, content, Space(1.2)],
                Point2f[
                    (0, y0),
                    (hline_x, line_y),
                    (rightinkbound(radical), 0),
                    (rightinkbound(content), 0),
                ],
            )
        elseif head == :text
            modifier, content = args
            new_state = add_font_modifier(state, modifier)
            new_state = change_mode(new_state, :text)
            return tex_layout(content, new_state)
        elseif head == :underover
            core, sub, super = tex_layout.(args, state)

            mid = hmid(core)
            dxsub = mid - hmid(sub) * shrink
            dxsuper = mid - hmid(super) * shrink

            under_offset = bottominkbound(core) - 0.1 - ascender(sub) * shrink
            over_offset = topinkbound(core) - descender(super)

            # The leftmost element must have x = 0
            x0 = -min(0, dxsub, dxsuper)
            y0 = 0.0

            return Group(
                [core, sub, super],
                Point2f[
                    (x0, y0),
                    (x0 + dxsub, y0 + under_offset),
                    (x0 + dxsuper, y0 + over_offset),
                ],
                [1, shrink, shrink];
                slanted = is_slanted(core),
            )
        elseif head == :unicode
            font_id, glyph_id = argument_as_string.(args)
            font_id = Symbol(font_id)
            font = get_font(state.font_family, font_id)
            glyph_id = glyph_index(font, Char(parse(Culong, glyph_id)))
            return TeXChar(glyph_id, font, state.font_family, false, '?')
        end
    catch
        # TODO Better error
        rethrow()
        @error "Error while layouting expr"
    end

    throw(ArgumentError("Unsupported head :$(head) in TeXExpr\n$expr"))
end

tex_layout(::Nothing, state) = Space(0)

"""
    horizontal_layout(elements)

Layout the elements horizontally, like normal text.
"""
function horizontal_layout(elements; italic_correction = false)
    if italic_correction
        elements = _italic_correction(elements)
    end

    dxs = hadvance.(elements)
    xs = [0, cumsum(dxs[1:(end - 1)])...]

    return Group(elements, Point2f.(xs, 0); slanted = is_slanted(last(elements)))
end

function _add_math_operator_spacing(args, elements)
    spaced = TeXElement[]

    for (i, elem) in enumerate(elements)
        push!(spaced, elem)
        if _is_spaced_math_operator(args[i]) && _operator_takes_space(args, i)
            push!(spaced, Space(1 / 6))
        end
    end

    return spaced
end

function _operator_takes_space(args, i)
    next = findnext(arg -> !(arg.head == :char && only(arg.args) == ' '), args, i + 1)
    return !isnothing(next) && !_is_opening_delimiter(args[next])
end

function _is_spaced_math_operator(arg)
    arg isa TeXExpr || return false
    arg.head == :function && return true
    return arg.head in (:decorated, :underover) && _is_spaced_math_operator(first(arg.args))
end

function _is_opening_delimiter(expr)
    return expr.head == :delimiter && only(expr.args) in ('(', '[', '⟨', '{')
end

function _italic_correction(elements)
    corrected = TeXElement[]

    for (i, elem) in enumerate(elements)
        if i > 1
            offset = italic_transition_offset(elements[i - 1], elem)
            if offset != 0
                push!(corrected, Space(offset))
            end
        end
        push!(corrected, elem)
    end

    return corrected
end

function italic_transition_offset(prev, elem)
    (prev isa Space || elem isa Space) && return 0.0

    if is_slanted(prev) && is_slanted(elem)
        return slanted_adjacent_offset(prev, elem)
    elseif !is_slanted(prev) && !is_slanted(elem)
        return 0.0
    end

    if is_slanted(prev) && !is_slanted(elem)
        height_prev = topinkbound(prev)
        height_prev <= 0 && return 0.0

        overhang = rightinkbound(prev) - hadvance(prev)
        overhang <= 0 && return 0.0

        height_elem = topinkbound(elem)
        return height_prev <= height_elem ? overhang : overhang * height_elem / height_prev
    elseif !is_slanted(prev) && is_slanted(elem)
        bearing = leftinkbound(elem)

        if bearing < 0
            depth_prev = inkheight(prev) - topinkbound(prev)
            depth_elem = inkheight(elem) - topinkbound(elem)
            depth_prev <= 0 && return 0.0
            return depth_prev >= depth_elem ? -bearing : -bearing * depth_prev / depth_elem
        end

        # Positive left bearings on italic glyphs make e.g. "(t)" look
        # asymmetric. Remove that extra font-side gap at roman-to-italic edges.
        return -bearing
    end

    return 0.0
end

function slanted_adjacent_offset(prev, elem)
    top = min(topinkbound(prev), topinkbound(elem))
    bottom = max(bottominkbound(prev), bottominkbound(elem))
    top <= bottom && return 0.0

    gap = hadvance(prev) + leftinkbound(elem) - rightinkbound(prev)
    min_gap = _SLANTED_ADJACENT_GAP * min(inkheight(prev), inkheight(elem))
    offset = min_gap - gap
    return max(0.0, min(offset, 2min_gap))
end

function layout_text(string, font_family)
    isempty(string) && return Space(0)

    elements = TeXChar.(collect(string), LayoutState(font_family), Ref(:text))
    return horizontal_layout(elements)
end

"""
    unravel(element::TeXElement, pos, scale)

Flatten the layouted TeXElement and produce a single list of base element with
their associated absolute position and scale.
"""
function unravel(group::Group, parent_pos = Point2f(0), parent_scale = 1.0f0)
    scales = group.scales .* parent_scale
    positions = [parent_pos .+ pos for pos in parent_scale .* group.positions]
    elements = []

    for (elem, pos, scale) in zip(group.elements, positions, scales)
        push!(elements, unravel(elem, pos, scale)...)
    end

    return elements
end

unravel(::Space, pos, scale) = []
unravel(element, pos, scale) = [(element, pos, scale)]

"""
    generate_tex_elements(str)

Create a list of tuple `(texelement, position, scale)` from a string
of LaTeX math mode code. The elements' positions and scales are such as to
approximatively reproduce the LaTeX output.

The elments are of one of the following types

    - `TeXChar` a (unicode) character with a specific font.
    - `HLine` a horizontal line.
    - `VLine` a vertical line.
"""
function generate_tex_elements(str, font_family = FontFamily())
    expr = texparse(str)

    for node in PreOrderDFS(expr)
        if node isa TeXExpr && node.head == :fontfamily
            # Reconstruct the argument as a single string
            name = join([texchar.args[1] for texchar in node.args[1].args])
            font_family = FontFamily(name)
            break
        end
    end
    layout = tex_layout(expr, font_family)
    return unravel(layout)
end
