"""
    tex_layout(mathexpr::TeXExpr, fontset)

Recursively determine the layout of the math expression represented the given
TeXExpr for the given font set.
"""
function tex_layout(expr, fontset)
    head = expr.head
    args = [expr.args...]
    shrink = 0.6

    try
        if head in [:char, :delimiter, :digit, :punctuation, :symbol]
            char = args[1]
            return TeXChar(char, fontset, head)
        elseif head == :combining_accent
            accent, core = tex_layout.(args, Ref(fontset))

            y = topinkbound(core) - xheight(fontset)

            if core.slanted
                α = slant_angle(fontset)
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
            core, sub, super = tex_layout.(args, Ref(fontset))
            
            core_width = advance(core)

            return Group(
                [core, sub, super],
                Point2f[
                    (0, 0),
                    (core_width, -0.2),
                    (core_width, xheight(core) - 0.5 * descender(super))],
                [1, shrink, shrink]
            )
        elseif head == :delimited
            elements = tex_layout.(args, Ref(fontset))
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
            # TODO
        elseif head == :frac
            numerator = tex_layout(args[1], fontset)
            denominator = tex_layout(args[2], fontset)

            # extend fraction line by half an xheight
            xh = xheight(fontset)
            w = max(inkwidth(numerator), inkwidth(denominator)) + xh/2

            # fixed width fraction line
            lw = thickness(fontset)

            line = HLine(w, lw)
            y0 = xh/2 - lw/2

            # horizontal center align for numerator and denominator
            x1 = (w-inkwidth(numerator))/2
            x2 = (w-inkwidth(denominator))/2

            ytop    = y0 + xh/2 - bottominkbound(numerator)
            ybottom = y0 - xh/2 - topinkbound(denominator)

            return Group(
                [line, numerator, denominator],
                Point2f[(0,y0), (x1, ytop), (x2, ybottom)]
            )
        elseif head == :function
            name = args[1]
            elements = TeXChar.(collect(name), Ref(fontset), Ref(:function))
            return horizontal_layout(elements)
        elseif head == :group || head == :expr
            elements = tex_layout.(args, Ref(fontset))
            return horizontal_layout(elements)
        elseif head == :integral
            pad = 0.1
            sub, super = tex_layout.(args[2:3], Ref(fontset))

            # Always use ComputerModern fallback for the integral sign
            # as the Unicode LaTeX approach requires to use glyph variant
            # which is unlikely to be supported by backends
            intfont = load_font(joinpath("ComputerModern", "cmex10.ttf"))
            int = TeXChar(Char(0x5a), intfont)
            h = inkheight(int)

            return Group(
                [int, sub, super],
                Point2f[
                    (0, h/2 + xheight(fontset)/2),
                    (
                        0.15 - inkwidth(sub)*shrink/2,
                        -h/2 + xheight(fontset)/2 - topinkbound(sub)*shrink - pad
                    ),
                    (
                        0.85 - inkwidth(super)*shrink/2,
                        h/2 + xheight(fontset)/2 + pad
                    )
                ],
                [1, shrink, shrink]
            )
        elseif head == :space
            return Space(args[1])
        elseif head == :spaced
            sym = tex_layout(args[1], fontset)
            return horizontal_layout([Space(0.2), sym, Space(0.2)])
        elseif head == :sqrt
            content = tex_layout(args[1], fontset)
            sqrt = TeXChar('√', fontset, :symbol)

            relpad = 0.15

            h = inkheight(content)
            ypad = relpad * h
            h += 2ypad

            if h > inkheight(sqrt)
                sqrt = TeXChar('⎷', fontset, :symbol)
            end

            h = max(inkheight(sqrt), h)

            # The root symbol must be manually placed
            y0 = bottominkbound(content) - bottominkbound(sqrt) - ypad/2
            y = y0 + bottominkbound(sqrt) + h
            xpad = advance(sqrt) - inkwidth(sqrt)
            w =  inkwidth(content) + 2xpad

            lw = thickness(fontset)
            hline = HLine(w, lw)
            vline = VLine(inkheight(sqrt) - h, lw)

            return Group(
                [sqrt, vline, hline, content],
                Point2f[
                    (0, y0),
                    (rightinkbound(sqrt) - lw/2, y),
                    (rightinkbound(sqrt) - lw/2, y - lw/2),
                    (advance(sqrt), 0)
                ]
            )

        elseif head == :underover
            core, sub, super = tex_layout.(args, Ref(fontset))

            mid = hmid(core)
            dxsub = mid - hmid(sub) * shrink
            dxsuper = mid - hmid(super) * shrink

            under_offset = bottominkbound(core) - (ascender(sub) - xheight(sub)/2) * shrink
            over_offset = topinkbound(core) - descender(super)

            # The leftmost element must have x = 0
            x0 = -min(0, dxsub, dxsuper)

            return Group(
                [core, sub, super],
                Point2f[
                    (x0, 0),
                    (x0 + dxsub, under_offset),
                    (x0 + dxsuper, over_offset)
                ],
                [1, shrink, shrink]
            )
        end
    catch
        # TODO Better error
        rethrow()
        @error "Error while processing expr"
    end

    @error "Unsupported head $(head) in expr:\n$expr"
end

tex_layout(::Nothing, fontset) = Space(0)

"""
    horizontal_layout(elements)

Layout the elements horizontally, like normal text.
"""
function horizontal_layout(elements)
    dxs = advance.(elements)
    xs = [0, cumsum(dxs[1:end-1])...]

    return Group(elements, Point2f.(xs, 0))
end

function layout_text(string, fontset)
    isempty(string) && return Space(0)

    elements = TeXChar.(collect(string), Ref(fontset), Ref(:text))
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

unravel(char::ScaledChar, pos, scale) = unravel(char.char, pos, scale*char.scale)
unravel(::Space, pos, scale) = []
unravel(element, pos, scale) = [(element, pos, scale)]

"""
    generate_tex_elements(str)

Create a list of tuple `(texelement, position, scale)` from a string
of LaTeX math mode code. The elements' positions and scales are such as to
approximatively reproduce the LaTeX output.

The elments are of one of the following types
    - `TeXChar` a (unicode) character, in a specific font.
    - `HLine` a horizontal line.
    - `VLine` a vertical line.
"""
function generate_tex_elements(str, fontset=FontSet())
    expr = texparse(str)
    layout = tex_layout(expr, fontset)
    return unravel(layout)
end

# Still hacky as hell
function generate_tex_elements(str::LaTeXString, fontset=FontSet())
    parts = String.(split(str, raw"$"))
    groups = Vector{TeXElement}(undef, length(parts))
    texts = parts[1:2:end]
    maths = parts[2:2:end]

    groups[1:2:end] = layout_text.(texts, Ref(fontset))
    groups[2:2:end] = tex_layout.(texparse.(maths), Ref(fontset))

    return unravel(horizontal_layout(groups))
end