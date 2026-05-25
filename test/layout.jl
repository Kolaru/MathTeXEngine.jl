function test_same_layout(layout1, layout2)
    @test all(layout1.positions .== layout2.positions)
    @test all(layout1.scales .== layout2.scales)

    for (elem1, elem2) in zip(layout1.elements, layout2.elements)
        if elem1 isa TeXElement
            @test elem1 == elem2
        else
            test_same_layout(elem1, elem2)
        end
    end
    return
end

ink_bottom(element) = element[2][2] + element[3] * bottominkbound(element[1])
ink_left(element) = element[2][1] + element[3] * leftinkbound(element[1])
ink_right(element) = element[2][1] + element[3] * rightinkbound(element[1])
ink_top(element) = element[2][2] + element[3] * topinkbound(element[1])
ink_vmid(element) = (ink_bottom(element) + ink_top(element)) / 2
ink_group_vmid(elements) = (minimum(ink_bottom, elements) + maximum(ink_top, elements)) / 2

@testset "Layout" begin
    @testset "Decorated" begin
        expr = manual_texexpr((:decorated, 'x', 'b', 't'))
        layout = tex_layout(expr, FontFamily())
        @test length(layout.elements) == 3
        @test layout.positions[2][2] < layout.positions[3][2]
        @test layout.scales[1] == 1
        @test layout.scales[2] < 1
        @test layout.scales[3] < 1

        expr = manual_texexpr((:decorated, 'y', nothing, 't'))
        layout = tex_layout(expr, FontFamily())
        @test layout.elements[2] == Space(0)

        expr = manual_texexpr((:decorated, 'z', 'b', nothing))
        layout = tex_layout(expr, FontFamily())
        @test layout.elements[3] == Space(0)

        @test length(generate_tex_elements(L"a_b^c")) == 3
        @test length(generate_tex_elements(L"_b^c")) == 2

        elems = generate_tex_elements(L"\left(\frac{dy}{dx}\right)_0")
        @test ink_bottom(elems[8]) < ink_bottom(elems[7]) - 0.03
        @test ink_top(elems[8]) > ink_bottom(elems[7])

        elems = generate_tex_elements(L"\left(\frac{A^{xy}}{B}\right)^{1/4}")
        @test ink_top(elems[8]) > ink_top(elems[7]) + 0.03
        @test ink_bottom(elems[8]) < ink_top(elems[7])

        @test generate_tex_elements(L"W^{(i+j)}")[2][3] ≈ 0.6
        @test generate_tex_elements(L"x_{y \rightarrow 0}")[2][3] ≈ 0.6

        ordinary_elems = generate_tex_elements(L"V^1_2")
        sub_start = ordinary_elems[2][2][1] +
            ordinary_elems[2][3] * leftinkbound(ordinary_elems[2][1])
        super_start = ordinary_elems[3][2][1] +
            ordinary_elems[3][3] * leftinkbound(ordinary_elems[3][1])
        @test sub_start < super_start

        star_elems = generate_tex_elements(L"x^*")
        @test ink_top(star_elems[2]) > ink_top(star_elems[1])
        @test ink_bottom(star_elems[2]) < xheight(FontFamily()) + 0.05
    end

    @testset "Delimited" begin
        expr = manual_texexpr((:delimited, '(', L"\sum_a^b", ')'))
        layout = tex_layout(expr, FontFamily())

        hs = inkheight.(layout.elements) .* layout.scales
        @test hs[1] >= hs[2]
        @test hs[3] >= hs[2]

        simple_elems = generate_tex_elements(L"\left(1 + 2\right)")
        simple_axis = ink_group_vmid(simple_elems[[2, 4]])
        @test ink_vmid(simple_elems[1]) ≈ simple_axis atol = 0.01
        @test ink_vmid(simple_elems[end]) ≈ simple_axis atol = 0.01

        capital_elems = generate_tex_elements(L"\left{A + B\right}")
        capital_axis = ink_group_vmid(capital_elems[[2, 4]])
        @test ink_vmid(capital_elems[1]) ≈ capital_axis atol = 0.01
        @test ink_vmid(capital_elems[end]) ≈ capital_axis atol = 0.01

        fraction_elems = generate_tex_elements(L"\left(\frac{1}{2}\right)")
        fraction_axis = max(ink_group_vmid(fraction_elems[2:(end - 1)]), xheight(FontFamily()) / 2)
        @test ink_vmid(fraction_elems[1]) ≈ fraction_axis atol = 0.01
        @test ink_vmid(fraction_elems[end]) ≈ fraction_axis atol = 0.01

        descender_fraction_elems = generate_tex_elements(L"\left[\frac{a}{b}\right]")
        @test ink_bottom(descender_fraction_elems[1]) <= ink_bottom(descender_fraction_elems[end - 1])
        @test ink_top(descender_fraction_elems[1]) >= ink_top(descender_fraction_elems[2])

        greek_brace_fraction_elems = generate_tex_elements(L"\left{\frac{\alpha}{\beta}\right}")
        @test greek_brace_fraction_elems[1][3] < descender_fraction_elems[1][3]

        nested_elems = generate_tex_elements(L"\left{1 + \left[2 + \left(3 + 4\right)\right]\right}")
        nested_axis = ink_group_vmid(nested_elems[[2, 5, 8, 10]])
        nested_delimiters = nested_elems[[1, 4, 7, 11, 12, 13]]
        @test maximum(abs(ink_vmid(elem) - nested_axis) for elem in nested_delimiters) < 0.015

        elems = generate_tex_elements(
            L"\left\langle\left|\left\langle\left|\int\right|\right\rangle\right|\right\rangle",
        )
        @test maximum(abs(ink_vmid(elem) - ink_vmid(elems[5])) for elem in elems) < 0.1

        for font_name in keys(MathTeXEngine.default_font_families)
            bar = tex_layout(manual_texexpr((:delimiter, '|')), MathTeXEngine.FontFamily(font_name))
            default_bar_id, _ = MathTeXEngine.default_math_glyph('|')
            @test bar.glyph_id == default_bar_id

            paren = tex_layout(manual_texexpr((:delimiter, '(')), MathTeXEngine.FontFamily(font_name))
            default_paren_id, _ = MathTeXEngine.default_math_glyph('(')
            @test paren.glyph_id == default_paren_id
        end
    end

    @testset "Font" begin
        expr = manual_texexpr((:char, 'u'))
        texchar = tex_layout(expr, FontFamily())
        @test isa(texchar, TeXChar)

        expr = manual_texexpr((:font, :rm, 'u'))
        texchar = tex_layout(expr, FontFamily())
        @test isa(texchar, TeXChar)

        font_family = FontFamily()
        bold_font = MathTeXEngine.get_font(font_family, :bold)
        bold_special_chars = [
            char for char in keys(font_family.special_chars)
                if MathTeXEngine.glyph_index(bold_font, char) != 0
        ]
        @test !isempty(bold_special_chars)

        for char in bold_special_chars
            expr = manual_texexpr((:font, :bf, (:symbol, char)))
            texchar = tex_layout(expr, font_family)
            @test texchar.font == bold_font
            @test texchar.glyph_id == MathTeXEngine.glyph_index(bold_font, char)

            expr = manual_texexpr((:boldsymbol, (:symbol, char)))
            texchar = tex_layout(expr, font_family)
            @test texchar.font == bold_font
            @test texchar.glyph_id == MathTeXEngine.glyph_index(bold_font, char)
        end

        elems = generate_tex_elements(L"\boldsymbol{\nabla}")
        @test length(elems) == 1
        @test only(elems)[1].glyph_id != 0
    end

    @testset "Group" begin
        expr = manual_texexpr((:group, 'a', 'b', 'c'))
        layout = tex_layout(expr, FontFamily())
        @test length(layout.elements) == 3
        @test length(layout.positions) == 3
        @test length(layout.scales) == 3
        @test all([pos[2] == 0 for pos in layout.positions])
        @test all(layout.scales .== 1)

        expr = manual_texexpr((:group, 'x', (:group, 'y')))
        layout = tex_layout(expr, FontFamily())
        subexpr = manual_texexpr((:group, 'y'))
        sublayout = tex_layout(subexpr, FontFamily())
        @test length(layout.elements) == 2
        @test length(layout.positions) == 2
        @test length(layout.scales) == 2
        test_same_layout(sublayout, layout.elements[2])

        @test isempty(generate_tex_elements(L"{}"))
        @test isempty(generate_tex_elements(L""))
    end

    @testset "Space" begin
        elems = generate_tex_elements(L"\quad a")
        @test length(elems) == 1
        char, pos, size = first(elems)
        @test pos[1] == 1

        elems = generate_tex_elements(L"\qquad b")
        @test length(elems) == 1
        char, pos, size = first(elems)
        @test pos[1] == 2
    end

    @testset "Italic boundary correction" begin
        old = MathTeXEngine.italic_correction_enabled[]
        try
            MathTeXEngine.italic_correction_enabled[] = false
            without = generate_tex_elements(L"(f)x η(t)")

            MathTeXEngine.italic_correction_enabled[] = true
            with = generate_tex_elements(L"(f)x η(t)")

            xpos(elems, i) = elems[i][2][1]

            # Issue #142: roman delimiters next to italic glyphs should not
            # inherit an asymmetric font-side gap.
            @test xpos(with, 2) > xpos(without, 2)
            @test xpos(with, 3) > xpos(without, 3)

            # Issue #95: the same boundary correction also applies to lower
            # case Greek followed by roman delimiters in subscripts/labels.
            @test MathTeXEngine.is_slanted(with[5][1])
            @test xpos(with, 7) - xpos(with, 6) < xpos(without, 7) - xpos(without, 6)
            @test xpos(with, 8) - xpos(with, 7) > xpos(without, 8) - xpos(without, 7)

            MathTeXEngine.italic_correction_enabled[] = false
            without = generate_tex_elements(L"k\xi")
            MathTeXEngine.italic_correction_enabled[] = true
            with = generate_tex_elements(L"k\xi")

            # Adjacent slanted glyphs can still collide even without a
            # roman/italic transition. Keep a small ink gap for cases like kξ.
            @test ink_left(with[2]) - ink_right(with[1]) >
                ink_left(without[2]) - ink_right(without[1])
            @test ink_left(with[2]) - ink_right(with[1]) > 0.01
        finally
            MathTeXEngine.italic_correction_enabled[] = old
        end
    end

    @testset "Function spacing" begin
        xpos(elems, i) = elems[i][2][1]
        inline_layout(expr) = tex_layout(texparse(expr), FontFamily()).elements[1]

        # Issue #129: LaTeX inserts a thin space after math operators when
        # the argument is not parenthesized.
        @test xpos(generate_tex_elements(L"\log x"), 4) >
            xpos(generate_tex_elements(L"\mathrm{log}x"), 4) + 0.1
        @test xpos(generate_tex_elements(L"\sin\alpha"), 4) >
            xpos(generate_tex_elements(L"\mathrm{sin}\alpha"), 4) + 0.1
        @test inline_layout(L"\inf_x\tan(x)").elements[2] == Space(1 / 6)
        @test inline_layout(L"\sup_x\tan(x)").elements[2] == Space(1 / 6)

        # No operator space is inserted before an opening delimiter.
        @test xpos(generate_tex_elements(L"\log(x)"), 4) ≈
            xpos(generate_tex_elements(L"\mathrm{log}(x)"), 4)
        @test !(inline_layout(L"\inf_x(\tan(x))").elements[2] isa Space)
    end

    @testset "Fraction rule padding" begin
        elems = generate_tex_elements(L"\frac{1}{2}")
        rule_start = elems[1][2][1] + elems[1][3] * leftinkbound(elems[1][1])
        rule_end = elems[1][2][1] + elems[1][3] * rightinkbound(elems[1][1])
        numerator_start = elems[2][2][1] + elems[2][3] * leftinkbound(elems[2][1])
        denominator_end = elems[3][2][1] + elems[3][3] * rightinkbound(elems[3][1])
        @test numerator_start - rule_start > 0.1
        @test rule_end - denominator_end > 0.1
        @test abs((numerator_start - rule_start) - (rule_end - denominator_end)) < 0.05

        elems = generate_tex_elements(L"x^{\frac{1}{1+2}}")
        rule_end = elems[2][2][1] + elems[2][3] * rightinkbound(elems[2][1])
        denom_end = maximum(e[2][1] + e[3] * rightinkbound(e[1]) for e in elems[4:6])
        @test rule_end - denom_end < 0.1
    end

    @testset "Square root glyph fallback" begin
        for font_name in keys(MathTeXEngine.default_font_families)
            elems = generate_tex_elements(L"\sqrt{3}", MathTeXEngine.FontFamily(font_name))
            @test elems[1][1] isa TeXChar
            @test elems[1][1].represented_char == '√'
            @test elems[1][1].glyph_id != 0
            @test ink_top(elems[2]) ≈ ink_top(elems[1]) atol = 1.0e-6

            empty_elems = generate_tex_elements(L"\sqrt{}", MathTeXEngine.FontFamily(font_name))
            @test empty_elems[1][1].represented_char == '√'
            @test empty_elems[1][1].glyph_id != 0
            @test rightinkbound(empty_elems[2][1]) > 0

            tall_elems = generate_tex_elements(
                L"\sqrt{x_i^2+y_i^2}",
                MathTeXEngine.FontFamily(font_name),
            )
            @test ink_bottom(tall_elems[2]) >= maximum(ink_top(e) for e in tall_elems[3:end])
        end

        frac_elems = generate_tex_elements(L"\sqrt{\frac{1}{2}}")
        @test ink_bottom(frac_elems[2]) - maximum(ink_top(e) for e in frac_elems[3:end]) >
            xheight(MathTeXEngine.FontFamily()) / 3
        @test ink_bottom(frac_elems[2]) - maximum(ink_top(e) for e in frac_elems[3:end]) <
            0.55 * xheight(MathTeXEngine.FontFamily())
        @test minimum(ink_bottom(e) for e in frac_elems[3:end]) - ink_bottom(frac_elems[1]) <
            xheight(MathTeXEngine.FontFamily())
        @test ink_right(frac_elems[2]) - maximum(ink_right(e) for e in frac_elems[3:end]) <
            0.1

        simple_elems = generate_tex_elements(L"\sqrt{b^2 - 4ac}")
        @test ink_bottom(simple_elems[1]) > -0.4
    end

    @testset "Missing math symbols use default math fallback" begin
        for font_name in keys(MathTeXEngine.default_font_families)
            elems = generate_tex_elements(L"\int_0^1 f(x) dx", MathTeXEngine.FontFamily(font_name))
            @test elems[1][1] isa TeXChar
            @test elems[1][1].represented_char == '∫'
            @test elems[1][1].glyph_id != 0
        end

        elems = generate_tex_elements(L"\int", MathTeXEngine.FontFamily("NewComputerModern"))
        @test inkheight(elems[1][1]) > 2.0

        nested_elems = generate_tex_elements(
            L"\left\langle\left|\int\right|\right\rangle",
            MathTeXEngine.FontFamily("NewComputerModern"),
        )
        @test all(e -> e[1].glyph_id != 0, nested_elems)
        @test nested_elems[3][3] == 1
        @test nested_elems[1][3] < 1.5
        @test abs(ink_vmid(nested_elems[1]) - ink_vmid(nested_elems[3])) < 0.05
        @test abs(ink_vmid(nested_elems[2]) - ink_vmid(nested_elems[3])) < 0.05
    end

    @testset "Subscript spacing respects italic overhangs" begin
        ink_start(element) = element[2][1] + element[3] * leftinkbound(element[1])
        ink_end(element) = element[2][1] + element[3] * rightinkbound(element[1])

        font_names = sort(collect(keys(MathTeXEngine.default_font_families)))
        for font_name in font_names
            elems = generate_tex_elements(L"x_{\alpha(k)}", MathTeXEngine.FontFamily(font_name))
            @test ink_end(elems[1]) - ink_start(elems[2]) < 0.04
        end

        for font_name in font_names, tex in (L"N_\nu", L"J_\nu", L"V_\nu")
            elems = generate_tex_elements(tex, MathTeXEngine.FontFamily(font_name))
            @test elems[2][2][1] ≈ hadvance(elems[1][1])
            @test ink_start(elems[2]) < ink_end(elems[1])
        end

        for tex in (L"\mathrm{N}_\nu", L"\mathrm{J}_\nu")
            elems = generate_tex_elements(tex)
            @test ink_start(elems[2]) + 0.002 >= ink_end(elems[1])
        end

        elems = generate_tex_elements(L"N_\nu L_\nu A_\nu J_\nu")
        @test ink_start(elems[2]) < ink_end(elems[1])
        @test ink_start(elems[8]) < ink_end(elems[7])

        # Issue #95 includes a nested subscript case where the inner `(k)`
        # should stay inside the lower script instead of being squeezed left.
        for font_name in font_names
            elems = generate_tex_elements(
                L"v_{(a + b)_k}^i",
                MathTeXEngine.FontFamily(font_name),
            )
            @test ink_start(elems[7]) + 0.002 >= ink_end(elems[6])
        end
    end
end

@testset "Generate elements" begin
    elems = generate_tex_elements(L"a + b")
    @test length(elems) == 3

    elems = generate_tex_elements(L"{{a + b} - {c * d}}")
    @test length(elems) == 7

    # Check the following does not error
    tex =
        L"\lim_{α →\infty} A^j v_{(a + b)_k}^i \sqrt{2} x!= \sqrt{\frac{1+2}{4+a+x}}\int_{0}^{2π} \sin(x) dx"
    generate_tex_elements(tex)

    tex = L"Momentum $p_x$ (a.u.)"
    generate_tex_elements(tex)

    tex = L"Average $\overline{an}_i$"
    @test length(generate_tex_elements(tex)) == 12

    elems = generate_tex_elements(L"Time $t_0$")
    @test length(elems) == 7
end
