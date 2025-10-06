## flag to enable italic correction heuristic
const ITALIC_CORRECTION = Ref(true)
## percentage of x-pixelsize of font (like LetterSpacing in fontspec)
## for bearing before slanted glyph when switching from upright to slanted letters
const ITALIC_CORRECTION_LETTER_SPACING_UP_TO_IT = Ref(0.75f0) 

"""
Return the y value needed for the element to be vertically centered in the
middle of the xheight.
"""
function y_for_centered(font_family, elem)
    h = inkheight(elem)
    return h/2 + xheight(font_family)/2
end

function argument_as_string(arg)
    return String(Char.(arg.args))
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
    inside_math = state.tex_mode == :inline_math
    try
        if isleaf(expr)  # :char, :delimiter, :digit, :punctuation, :symbol
            char = args[1]
            if char == ' ' && state.tex_mode == :inline_math
                return Space(0.0)
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
                Point2f[
                    (0, 0),
                    (x + hmid(core) - hmid(accent), y)
                ],
                [1, 1]
            )
        elseif head == :decorated
            core, sub, super = tex_layout.(args, state)

            if !isnothing(args[3]) && args[3].head == :primes
                super_x = min(hadvance(core), rightinkbound(core)) - 0.1
                super_y = 0.1
                super_shrink = 1
            else
                super_x = max(hadvance(core), rightinkbound(core))
                super_y = xheight(font_family)
                super_shrink = shrink
            end

            return Group(
                [core, sub, super],
                Point2f[
                    (0, 0),
                    (
                        # The logic is to have the ink of the subscript starts
                        # where the ink of the unshrink glyph would
                        hadvance(core) + (1 - shrink) * leftinkbound(sub),
                        -0.2
                    ),
                    ( super_x, super_y)],
                [1, shrink, super_shrink]
            )
        elseif head == :delimited
            elements = tex_layout.(args, state)
            left, content, right = elements
            
            height = inkheight(content)
            left_scale = max(1, height / inkheight(left))
            right_scale = max(1, height / inkheight(right))
            scales = [left_scale, 1, right_scale]
 
            ## maybe add spaces for italic correction
            _elements = _italic_correction(Val(inside_math), elements, scales; ungroup_once=true)
            if length(_elements) > 3
                ## extra spaces have been added, regroup content
                left = first(_elements)
                right = last(_elements)
                content = horizontal_layout(_elements[2:end-1], false)
                elements = vcat(left, content, right)
            end
                    
            dxs = hadvance.(elements) .* scales
            xs = [0, cumsum(dxs[1:end-1])...]

            ## compute y-positions for delimiters
            # TODO Check what the algorithm should be there
            bot_content = bottominkbound(content)
            h_content = inkheight(content)
            h_left = inkheight(left) * left_scale
            delta_left = max(0, (h_left - h_content)) / 2
            y_left = bot_content - delta_left - (bottominkbound(left) * left_scale)

            h_right = inkheight(right) * right_scale
            delta_right = max(0, (h_right - h_content)) / 2
            y_right = bot_content - delta_right - (bottominkbound(right) * right_scale)
            return Group(elements, 
                Point2f[
                    (xs[1], y_left),
                    (xs[2], 0),
                    (xs[3], y_right)
                ],
                scales
            )
        elseif head == :font
            modifier, content = args
            return tex_layout(content, add_font_modifier(state, modifier))
        elseif head == :fontfamily
            return Space(0)
        elseif head == :frac
            numerator = tex_layout(args[1], state)
            denominator = tex_layout(args[2], state)

            # extend fraction line by half an xheight
            xh = xheight(font_family)
            w = max(inkwidth(numerator), inkwidth(denominator)) + xh/2

            # fixed width fraction line
            lw = thickness(font_family)

            line = HLine(w, lw)
            y0 = xh/2 - lw/2

            # horizontal center align for numerator and denominator
            x1 = (w-inkwidth(numerator))/2
            x2 = (w-inkwidth(denominator))/2

            ytop    = y0 + xh/2 - bottominkbound(numerator)
            ybottom = y0 - xh/2 - topinkbound(denominator)

            return Group(
                [line, numerator, denominator],
                Point2f[(0, y0), (x1, ytop), (x2, ybottom)]
            )
        elseif head == :function
            name = args[1]
            elements = TeXChar.(collect(name), state, Ref(:function))
            return horizontal_layout(elements, inside_math)
        elseif head == :glyph
            font_id, glyph_id = argument_as_string.(args)
            font_id = Symbol(font_id)
            glyph_id = parse(Culong, glyph_id)
            font = get_font(state.font_family, font_id)
            return TeXChar(glyph_id, font, state.font_family, false, '?')
        elseif head in (:group, :inline_math, :line)
            mode = (head == :inline_math) ? :inline_math : state.tex_mode
            elements = tex_layout.(args, change_mode(state, mode))
            if isempty(elements)
                return Space(0.0)
            end
            return horizontal_layout(elements, mode == :inline_math)
        elseif head == :integral
            pad = 0.1
            int, sub, super = tex_layout.(args, state)

            return Group(
                [int, sub, super],
                Point2f[
                    (0, 0),
                    (
                        0.15 - inkwidth(sub)*shrink/2,
                        bottominkbound(int) - topinkbound(sub)*shrink - pad
                    ),
                    (
                        0.85 - inkwidth(super)*shrink/2,
                        topinkbound(int) + pad
                    )
                ],
                [1, shrink, shrink]
            )
        elseif head == :lines
            length(args) == 1 && return tex_layout(only(args), state)
            lineheight = 1.3
            lines = tex_layout.(args, state)
            points = map(enumerate(lines)) do (k, line)
                x = -inkwidth(line) / 2
                y = (1 - k)*lineheight
                return Point2f(x, y)
            end

            return Group(lines, points)
        elseif head == :overline
            content = tex_layout(args[1], state)

            lw = thickness(font_family)
            y =  topinkbound(content) - lw

            hline = HLine(inkwidth(content) - 0.15, lw)

            return Group(
                [hline, content],
                Point2f[
                    (0.25, y + lw/2 + 0.2),
                    (0, 0)
                ]
            )
        elseif head == :primes
            primes = [TeXExpr(:char, ''') for _ in 1:only(args)]
            return horizontal_layout(tex_layout.(primes, state), inside_math)
        elseif head == :space
            return Space(args[1])
        elseif head == :spaced
            sym = tex_layout(args[1], state)
            return horizontal_layout([Space(0.2), sym, Space(0.2)], inside_math)
        elseif head == :sqrt
            content = tex_layout(args[1], state)
            h = inkheight(content)
            sqrt = nothing

            for name in ["radical.v1", "radical.v2", "radical.v3", "radical.v4"]
                sqrt = TeXChar(name, state, :symbol ; represented = '√')
                pad = inkheight(sqrt)
                if inkheight(sqrt) >= 1.05h
                    pad = (inkheight(sqrt) - 1.05h) / 2
                    break
                end
            end

            h = inkheight(sqrt)

            lw = thickness(font_family)
            y0 = bottominkbound(content) - bottominkbound(sqrt) - pad
            y = y0 + topinkbound(sqrt) - lw

            hline = HLine(inkwidth(content) + pad, lw)

            return Group(
                [sqrt, hline, content, Space(1.2)],
                Point2f[
                    (0, y0),
                    (rightinkbound(sqrt) - lw/2, y + lw/2),
                    (rightinkbound(sqrt), 0),
                    (rightinkbound(content), 0)
                ]
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
                    (x0 + dxsuper, y0 + over_offset)
                ],
                [1, shrink, shrink]
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
function horizontal_layout(elements, inside_math=false)
    elements = _italic_correction(Val(inside_math), elements)
    dxs = hadvance.(elements)
    xs = [0, cumsum(dxs[1:end-1])...]

    return Group(elements, Point2f.(xs, 0))
end

function layout_text(string, font_family)
    isempty(string) && return Space(0)

    elements = TeXChar.(collect(string), LayoutState(font_family), Ref(:text))
    return horizontal_layout(elements, false)
end

function _italic_correction(inside_math::Val{false}, elements, args...; kwargs...)
    return elements
end
function _italic_correction(inside_math::Val{true}, elements, scales=1; ungroup_once=false)
    global ITALIC_CORRECTION, ITALIC_CORRECTION_LETTER_SPACING_UP_TO_IT
    if ITALIC_CORRECTION[]
        @assert isa(scales, Number) || length(elements) == length(scales)
        elems = vcat(Space(0), elements)
        j = 1
        for (i, elem) in enumerate(elements)
            i == 1 && continue
            prev = elements[i-1]
            if isa(prev, Group) && ungroup_once
                prev = last(prev.elements)
            end
            !isa(prev, TeXChar) && continue

            if isa(elem, Group) && ungroup_once
                elem = first(elem.elements)
            end
            !isa(elem, TeXChar) && continue
            
            scale_elem = _get_scale(scales, i)
            scale_prev = _get_scale(scales, i-1)

            if prev.slanted != elem.slanted
                offset = 0
                #=
                glyph metrics defined in `sile/justenough/justenoughharfbuzz.c`;
                `height` (== `y_bearing`)   ⇔ `topinkbound`
                `tHeight`                   ⇔ `- inkheight`
                `width` (== `x_advance`)    ⇔ `hadvance`
                `x_bearing`                 ⇔ `hbearing_ori_to_left`
                `glyphWidth` (== `width`)   ⇔ `inkwidth`
                =#
                height_prev = topinkbound(prev) * scale_prev
                if prev.slanted && !elem.slanted && height_prev > 0
                    # `fromItalicCorrection` in `sile/typesetters/base.lua`
                    ## if previous glyph was slanted and printed width `d` is greater
                    ## than hadvance, then add difference to bearing of upright glyph
                    width_prev = hadvance(prev) * scale_prev
                    glyph_width_prev = inkwidth(prev) * scale_prev
                    bearing_x_prev = hbearing_ori_to_left(prev) * scale_prev
                    d = glyph_width_prev + bearing_x_prev
                    delta = d > width_prev ? d - width_prev : 0
                    height_elem = topinkbound(elem) * scale_elem
                    offset = height_prev <= height_elem ? delta : delta * height_elem / height_prev
                elseif !prev.slanted && elem.slanted 
                    # inspired by `toItalicCorrection` in `sile/typesetters/base.lua`
                    d = hbearing_ori_to_left(elem) * scale_elem
                    depth_prev = (inkheight(prev) - topinkbound(prev)) * scale_prev
                    depth_elem = (inkheight(elem) - topinkbound(elem)) * scale_elem
                    delta = -d
                    if d < 0 && depth_prev > 0
                        # `sile` formula
                        ## if previous glyph was upright and goes beyond baseline, 
                        ## if and current glyph has a negative bearing,
                        ## then increase bearing by flipping sign of bearing distance
                        offset = depth_prev >= depth_elem ? delta : delta * depth_prev / depth_elem
                    elseif d >= 0
                        ## but also remove/reduce positive bearing or reduce it to some
                        ## minimum spacing value
                        fac = ITALIC_CORRECTION_LETTER_SPACING_UP_TO_IT[] / 100
                        b = fac == 0 ? 0 : fac * _font_pixelsize(prev)
                        offset = b + delta
                    end
                end
                if offset != 0
                    insert!(elems, i+j, Space(offset))
                    j+=1
                end
            end
        end
        popfirst!(elems)
        elements = elems
    end
    return elements
end

_get_scale(scales::Number, i)=scales
_get_scale(scales, i)=scales[i]

# obtain horizontal size of EM-box of font of `tchar` in pixels
function _font_pixelsize(tchar::TeXChar)
    font = tchar.font
    pxsize = @lock font.lock begin
        font.max_advance_width / font.units_per_EM
    end
    return pxsize
end

"""
    unravel(element::TeXElement, pos, scale)

Flatten the layouted TeXElement and produce a single list of base element with
their associated absolute position and scale.
"""
function unravel(group::Group, parent_pos=Point2f(0), parent_scale=1.0f0)
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
function generate_tex_elements(str, font_family=FontFamily())
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