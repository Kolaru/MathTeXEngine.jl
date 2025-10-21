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

    math_table = get_math_table(font_family)
    default_rule_thickness = get_math_constant(math_table, :fractionRuleThickness, thickness(font_family), true)

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
            ## within this conditional we determine several layouting constants;
            ## for the typesetting heuristics refer to
            ## Appendix G in https://visualmatheditor.equatheque.net/doc/texbook.pdfl
            ## for information on the OpenType Math names refer to
            ## https://learn.microsoft.com/en-us/typography/opentype/spec/math#math-table-structures
            ## for name mapping between OpenType and Tex refer to
            ## 7.4.2 in https://mirrors.ibiblio.org/CTAN/systems/doc/luatex/luatex.pdf

            ## layout nucleus
            core = tex_layout(args[1], state)

            ## before layouting sub- and superscript, we have to determine the current scaling factors
            ### special treatment for primes
            sup_is_primes = (!isnothing(args[3]) && args[3].head == :primes)
            
            script_shrink = if state.script_level[] <= 0
                get_math_constant(math_table, :scriptPercentScaleDown, 80) / 100
            else
                get_math_constant(math_table, :scriptScriptPercentScaleDown, 60) / 100
            end
            sub_shrink = script_shrink / state.script_scale[]
            sup_shrink = (sup_is_primes ? state.script_scale[] : script_shrink) / state.script_scale[]

            ## layout sub- and superscript
            sub = tex_layout(args[2], inc_script_level(state, sub_shrink))
            super = tex_layout(args[3], inc_script_level(state, sup_shrink))
            
            ## Y-Positions
            _1_5_x_height = abs(1/5 * xheight(font_family)) 
            sub1 = get_math_constant(math_table, :subscriptShiftDown, 0, true)
            sub2 = get_math_constant(math_table, :subscriptShiftDownWithSuperscript, sub1, true)    # not (yet) in OpenType standard, so will equal sub1
            sub_drop = get_math_constant(math_table, :subscriptBaselineDropMin, 0, true)
            sub_topmax = get_math_constant(math_table, :subscriptTopMax, 4 * _1_5_x_height, true)

            sup1 = sup_is_primes ? 0 : get_math_constant(math_table, :superscriptShiftUp, 0, true)
            sup_drop = get_math_constant(math_table, :superscriptBaselineDropMax, 0, true)
            sup_botmin = get_math_constant(math_table, :superscriptBottomMin, _1_5_x_height, true)
            sup_botmax = get_math_constant(math_table, :superscriptBottomMaxWithSubscript, 4 * sup_botmin, true)

            gap_min = get_math_constant(math_table, :subSuperscriptGapMin, 4 * default_rule_thickness, true)

            ### 18a -- Appendix G in TeXBook
            atomic_core = isa(core, TeXChar) || isa(core, Space)
            ### preliminary (positive) offsets
            v = atomic_core ? 0 : -bottominkbound(core) + sub_drop
            u = atomic_core ? 0 : topinkbound(core) - sup_drop
            
            sub_height = topinkbound(sub) * sub_shrink
            sup_depth = -bottominkbound(super) * sup_shrink

            empty_elem = Space(0)

            if sub != empty_elem && super == empty_elem
                ### 18b no superscript
                v = max(v, sub1, sub_height - sub_topmax)
            else
                v = max(v, sub2)
                ### 18c
                u = max(u, sup1, sup_depth + sup_botmin)
                if sub != empty_elem
                    ### nontrivial sub- and superscripts
                    _u = u - sup_depth
                    _v = sub_height - v
                    if _u - _v < gap_min
                        ### 18e
                        psi = sup_botmax - _u
                        if psi > 0
                            u += psi
                            v -= psi
                        else
                            #### TODO unsure about this
                            psi = gap_min - (_u - _v)
                            v += psi
                        end
                    end                        
                end
            end
            super_y = u
            sub_y = -v
            
            ## X-Positions
            sup_delta = 0   # TODO proper kerning/italic correction usign OpenType data
            sub_delta = 0   # min(0, -leftinkbound(sub) * sub_shrink) * 0.8f0  # with italic glyphs and positive left bearing, there is too much space
            #=
            old logic:
            `sub_delta = (1 - sub_shrink) * leftinkbound(sub)`
                # The logic is to have the ink of the subscript starts
                # where the ink of the unshrink glyph would
            =#

            super_x = max(hadvance(core), rightinkbound(core)) + sup_delta
            sub_x = hadvance(core) + sub_delta

            ## add post spaces in script boxes
            script_space = get_math_constant(math_table, :spaceAfterScript, 1/24, true)
            if state.nesting_state.level > 1
                ## TODO this is not standard
                script_space *= .25f0
            end
            
            sub = sub == empty_elem ? sub : Group([sub, Space(script_space / sub_shrink)], [Point2f(0, 0), Point2f(hadvance(sub), 0)])
            super = super == empty_elem ? super : Group([super, Space(script_space / sup_shrink)], [Point2f(0, 0), Point2f(hadvance(super), 0)])
            
            return Group(
                [core, sub, super],
                Point2f[
                    (0, 0),
                    (sub_x, sub_y),
                    (super_x, super_y)],
                [1, sub_shrink, sup_shrink]
            )
        elseif head == :delimited
            elements = tex_layout.(args, state)
            left, content, right = elements

            height = inkheight(content)
            left_scale = max(1, height / inkheight(left))
            right_scale = max(1, height / inkheight(right))
            scales = [left_scale, 1, right_scale]
                
            dxs = hadvance.(elements) .* scales
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
            return horizontal_layout(elements)
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
            return horizontal_layout(elements)
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
            len = only(args)
            primes = if len == 1
                [TeXExpr(:symbol, '′'),]
            elseif len == 2
                [TeXExpr(:symbol, '″'),]
            elseif len == 3
                [TeXExpr(:symbol, '‴'),]
            else
                reduce(vcat, [Space(-3/36), TeXExpr(:char, '′')] for _ in 1:len)
            end
            return horizontal_layout(tex_layout.(primes, state))
        elseif head == :space
            return Space(args[1])
        elseif head == :spaced
            sym = tex_layout(args[1], state)
            return horizontal_layout([Space(0.2), sym, Space(0.2)])
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
function horizontal_layout(elements)
    dxs = hadvance.(elements)
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