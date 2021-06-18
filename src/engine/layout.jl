"""
    tex_layout(mathexpr::TeXExpr, fontset)

Recursively determine the layout of the math expression represented the given
TeXExpr for the given font set.

Currently the only supported font set is NewComputerModern.
"""
function tex_layout(expr, fontset)
    head = expr.head
    args = [expr.args...]
    n = length(args)
    shrink = 0.6

    try
        if head == :group || head == :expr
            elements = tex_layout.(args, Ref(fontset))
            return horizontal_layout(elements)
        elseif head == :decorated
            core, sub, super = tex_layout.(args, Ref(fontset))
            
            core_width = advance(core)

            return Group(
                [core, sub, super],
                Point2f0[
                    (0, 0),
                    (core_width, -0.2),
                    (core_width, xheight(core) - 0.5 * descender(super))],
                [1, shrink, shrink])
        elseif head == :integral
            pad = 0.2
            sub, super = tex_layout.(args[2:3], Ref(fontset))

            # TODO Generalize this to other symbols ? This should be decided by the
            # fontset
            topint = TeXChar('⌠', fontset, :symbol, raw"\inttop")
            botint = TeXChar('⌡', fontset, :symbol, raw"\intbottom")

            top = Group([topint, super],
                Point2f0[
                    (0, 0),
                    (rightinkbound(topint) + pad, topinkbound(topint) - xheight(super))
                ],
                [1, shrink])
            bottom = Group([botint, sub],
                Point2f0[
                    (0, 0),
                    (rightinkbound(botint) + pad, bottominkbound(botint))
                ],
                [1, shrink])

            return Group(
                [top, bottom],
                Point2f0[
                    (0, xheight(fontset)/2),
                    (0, xheight(fontset)/2 - inkheight(botint) - bottominkbound(botint))
                ],
                [1, 1]
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
                Point2f0[
                    (x0, 0),
                    (x0 + dxsub, under_offset),
                    (x0 + dxsuper, over_offset)
                ],
                [1, shrink, shrink]
            )
        elseif head == :function
            name = args[1]
            elements = TeXChar.(collect(name), Ref(fontset), Ref(:function))
            return horizontal_layout(elements)
        elseif head == :space
            return Space(args[1])
        elseif head == :spaced
            char, command = args[1].args
            sym = TeXChar(char, fontset, :symbol, command)
            return horizontal_layout([Space(0.2), sym, Space(0.2)])
        elseif head == :delimited
            # TODO Parsing of this is crippling slow and I don't know why
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
                Point2f0[
                    (xs[1], -bottominkbound(left) + bottominkbound(content)),
                    (xs[2], 0),
                    (xs[3], -bottominkbound(right) + bottominkbound(content))
            ], scales)
        elseif head == :accent || head == :wide_accent
            # TODO
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
                Point2f0[(0,y0), (x1, ytop), (x2, ybottom)],
                [1,1,1]
                )
        elseif head == :sqrt
            content = tex_layout(args[1], fontset)
            sqrt = TeXChar('√', fontset, :symbol, raw"\sqrt")

            thick = thickness(fontset)
            relpad = 0.15

            h = inkheight(content)
            ypad = relpad * h
            h += 2ypad

            if h > inkheight(sqrt)
                sqrt = TeXChar('⎷', fontset, :symbol, raw"\sqrtbottom")
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
                Point2f0[
                    (0, y0),
                    (rightinkbound(sqrt) - lw/2, y),
                    (rightinkbound(sqrt) - lw/2, y - lw/2),
                    (advance(sqrt), 0)],
                [1, 1, 1, 1])
        elseif head == :symbol
            char, command = args
            return TeXChar(char, fontset, :symbol, command)
        end
    catch
        @warn "Error while processing expr"
        println(expr)
        rethrow()
    end

    @error "Unsupported expr $expr"
end

tex_layout(char::TeXChar, fontset) = char
tex_layout(::Nothing, fontset) = Space(0)

function tex_layout(char::Char, fontset)
    # TODO Move that to parser
    if char in "0123456789"
        char_type = :digit
    elseif char in ".,:;[]()"
        char_type = :punctuation
    else
        char_type = :variable
    end
    return TeXChar(char, fontset, char_type)
end

function horizontal_layout(elements ; scales=ones(length(elements)))
    dxs = advance.(elements)
    xs = [0, cumsum(dxs[1:end-1])...]

    return Group(elements, Point2f0.(xs, 0), scales)
end

"""
    unravel(element::TeXElement, pos, scale)

Flatten the layouted TeXElement and produce a single list of base element with
their associated absolute position and scale.
"""
function unravel(group::Group, parent_pos=Point2f0(0), parent_scale=1.0f0)
    positions = [parent_pos .+ pos for pos in parent_scale .* group.positions]
    scales = group.scales .* parent_scale
    elements = []

    for (elem, pos, scale) in zip(group.elements, positions, scales)
        push!(elements, unravel(elem, pos, scale)...)
    end

    return elements
end

unravel(char::ScaledChar, pos, scale) = unravel(char.char, pos, scale*char.scale)
unravel(::Space, pos, scale) = []
unravel(element, pos, scale) = [(element, pos, scale)]

function generate_tex_elements(str, fontset=FontSet())
    expr = texparse(str)
    layout = tex_layout(expr, fontset)
    return unravel(layout)
end

# Still hacky as hell
generate_tex_elements(str::LaTeXString, fontset=FontSet()) = generate_tex_elements(str[2:end-1], fontset)