"""
Return the y value needed for the element to be vertically centered in the
middle of the xheight.
"""
function y_for_centered(font_family, elem)
    h = inkheight(elem)
    return h/2 + xheight(font_family)/2
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

    try
        if head in [:char, :delimiter, :digit, :punctuation, :symbol]
            char = args[1]
            return TeXChar(char, state, head)
        elseif head == :combining_accent
            accent, core = tex_layout.(args, state)

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
            
            core_width = advance(core)

            return Group(
                [core, sub, super],
                Point2f[
                    (0, 0),
                    (core_width, -0.2),
                    (core_width, 0.8 * xheight(core))],
                [1, shrink, shrink]
            )
        elseif head == :delimited
            elements = tex_layout.(args, state)
            left, content, right = elements

            height = inkheight(content)
            left_scale = max(1, height / inkheight(left))
            right_scale = max(1, height / inkheight(right))
            scales = [left_scale, 1, right_scale]
                
            dxs = advance.(elements) .* scales
            xs = [0, cumsum(dxs[1:end-1])...]

            # TODO Height calculation for the parenthesis looks wrong
            # TODO Check what the algorithm should be there
            # Center the delimiters in the middle of the bot and top baselines ?
            return Group(elements, 
                Point2f[
                    (xs[1], -bottominkbound(left) + bottominkbound(content)),
                    (xs[2], 0),
                    (xs[3], -bottominkbound(right) + bottominkbound(content))
                ],
                scales
            )
        elseif head == :font
            modifier, content = args
            return tex_layout(content, add_font_modifier(state, modifier))
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
            return horizontal_layout(elements)
        elseif head == :group || head == :expr
            elements = tex_layout.(args, state)
            return horizontal_layout(elements)
        elseif head == :integral
            pad = 0.1
            sub, super = tex_layout.(args[2:3], state)

            # Always use ComputerModern fallback for the integral sign
            # as the Unicode LaTeX approach requires to use glyph variant
            # which is unlikely to be supported by backends
            intfont = load_font(joinpath("ComputerModern", "cmex10.ttf"))
            int = TeXChar(Char(0x5a), intfont)
            h = inkheight(int)

            return Group(
                [int, sub, super],
                Point2f[
                    (0, y_for_centered(font_family, int)),
                    (
                        0.15 - inkwidth(sub)*shrink/2,
                        -h/2 + xheight(font_family)/2 - topinkbound(sub)*shrink - pad
                    ),
                    (
                        0.85 - inkwidth(super)*shrink/2,
                        h/2 + xheight(font_family)/2 + pad
                    )
                ],
                [1, shrink, shrink]
            )
        elseif head == :space
            return Space(args[1])
        elseif head == :spaced
            sym = tex_layout(args[1], state)
            return horizontal_layout([Space(0.2), sym, Space(0.2)])
        elseif head == :sqrt
            content = tex_layout(args[1], state)
            sqrt = TeXChar('√', state, :symbol)

            relpad = 0.15

            h = inkheight(content)
            ypad = relpad * h
            h += 2ypad

            if h > inkheight(sqrt)
                sqrt = TeXChar('⎷', state, :symbol)
                h = inkheight(sqrt)
                y0 = (topinkbound(sqrt) - bottominkbound(sqrt))/2 + xheight(font_family)/2
            else
                y0 = bottominkbound(content) - bottominkbound(sqrt) - 0.1
            end

            lw = thickness(font_family)

            y = y0 + topinkbound(sqrt) - lw

            hline = HLine(inkwidth(content) + 0.1, lw)

            return Group(
                [sqrt, hline, content, Space(1.2)],
                Point2f[
                    (0, y0),
                    (rightinkbound(sqrt) - lw/2, y - lw/2),
                    (rightinkbound(sqrt), 0),
                    (rightinkbound(content), 0)
                ]
            )

        elseif head == :underover
            core, sub, super = tex_layout.(args, state)

            mid = hmid(core)
            dxsub = mid - hmid(sub) * shrink
            dxsuper = mid - hmid(super) * shrink

            under_offset = bottominkbound(core) - 0.1 - ascender(sub) * shrink
            over_offset = topinkbound(core) - descender(super)

            # The leftmost element must have x = 0
            x0 = -min(0, dxsub, dxsuper)

            # Special case to deal with sum symbols and the like that do not
            # have their baseline properly set in the font
            if core isa TeXChar
                y0 = y_for_centered(font_family, core)
            else
                y0 = 0.0
            end

            return Group(
                [core, sub, super],
                Point2f[
                    (x0, y0),
                    (x0 + dxsub, y0 + under_offset),
                    (x0 + dxsuper, y0 + over_offset)
                ],
                [1, shrink, shrink]
            )
        end
    catch
        # TODO Better error
        rethrow()
        @error "Error while layouting expr"
    end

    @error "Unsupported head $(head) in expr:\n$expr"
end

tex_layout(::Nothing, state) = Space(0)

"""
    horizontal_layout(elements)

Layout the elements horizontally, like normal text.
"""
function horizontal_layout(elements)
    dxs = advance.(elements)
    xs = [0, cumsum(dxs[1:end-1])...]

    return Group(elements, Point2f.(xs, 0))
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
    layout = tex_layout(expr, font_family)
    return unravel(layout)
end

# Still hacky as hell
function generate_tex_elements(str::LaTeXString, font_family=FontFamily())
    parts = String.(split(str, raw"$"))
    groups = Vector{TeXElement}(undef, length(parts))
    texts = parts[1:2:end]
    maths = parts[2:2:end]

    groups[1:2:end] = layout_text.(texts, Ref(font_family))
    groups[2:2:end] = tex_layout.(texparse.(maths), Ref(font_family))

    return unravel(horizontal_layout(groups))
end