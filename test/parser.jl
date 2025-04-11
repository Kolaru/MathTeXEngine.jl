function test_parse(input, args... ; broken=false)
    arg = (:line, args...)
    if broken
        @test_broken texparse(input) == manual_texexpr(arg)
    else
        @test texparse(input) == manual_texexpr(arg)
    end
end

@testset "Parser" begin
    @testset "Accent" begin
        # First char is the combining accent
        test_parse(
            raw"\dot{a}",
            (:combining_accent, '̇', 'a')
        )
        test_parse(
            raw"\vec{x}",
            (:combining_accent, '⃗', 'x')
        )
    end

    @testset "Delimiter" begin
        expr = texparse(L"\left(\frac{x}{y}\right)")
        delimited = expr.args[1].args[1]
        @test delimited.args[1].head == :delimiter
        @test delimited.args[2].head == :frac
        @test delimited.args[3].head == :delimiter

        test_parse(
            raw"\left(x\right)",
            (:delimited, '(', 'x', ')')
        )

        test_parse(
            raw"\left[y\right)",
            (:delimited, '[', 'y', ')')
        )

        test_parse(
            raw"\left(a+b\right)",
            (:delimited,
                '(',
                (:group, 'a', (:spaced, '+'), 'b'),
                ')'
            )
        )

        test_parse(raw"\{", (:delimiter, '{'))
        test_parse(raw"\}", (:delimiter, '}'))

        @test_throws TeXParseError texparse(raw"\left( x")
        @test_throws TeXParseError texparse(raw"x \right)")
    end

    @testset "Fonts" begin
        test_parse(raw"\mathrm{u}", (:font, :rm, (:char, 'u')))
        test_parse(raw"\text{u}", (:text, :rm, (:char, 'u')))

        test_parse(raw"\mathrm{u v}", (:text, :rm,
            (:group,
                (:char, 'u'),
                (:char, ' '),
                (:char, 'v')
            )))
        test_parse(raw"\text{u v}", (:text, :rm,
            (:group,
                (:char, 'u'),
                (:char, ' '),
                (:char, 'v')
            )))

        @test texparse(raw"ℝ") == texparse(raw"\mathbb{R}")
    end

    @testset "Fraction" begin
        test_parse(raw"\frac{1}{n}", (:frac, (:digit, '1'), 'n'))
    end

    @testset "Function" begin
        # Check that braces are not added to the function name
        test_parse(raw"\sin{x}", (:function, "sin"), 'x')
        test_parse(
            raw"\exp(x)",
            (:function, "exp"), '(', 'x', ')'
        )
        test_parse(
            raw"\tan\alpha",
            (:function, "tan"), (:symbol, 'α')
        )
    end

    @testset "Group" begin
        test_parse(raw"{x}", 'x')
        test_parse(raw"{fgh}", (:group, 'f', 'g', 'h'))
        test_parse(
            raw"{a{b{cd}}}",
            (:group, 'a', (:group, 'b', (:group, 'c', 'd')))
        )
        test_parse(raw"{}", (:space, 0.0))

        @test_throws TeXParseError texparse(raw"{v")
        @test_throws TeXParseError texparse(raw"w}")
    end

    @testset "Integral" begin
        test_parse(
            raw"\int",
            (:integral, (:symbol, '∫'), nothing, nothing)
        )
        test_parse(
            raw"\int_a^b",
            (:integral, (:symbol, '∫'), 'a', 'b')
        )
    end

    @testset "Linebreak" begin
        expr = texparse(L"$A$\\$B$\\$C$")
        @test expr.head == :lines
        @test length(expr.args) == 3
    end

    @testset "LaTeXString input" begin
        @test texparse(raw"$\gamma$") == texparse(L"\gamma")
    end

    @testset "Overunder" begin
        test_parse(
            raw"\sum",
            (:underover, (:symbol, '∑'), nothing, nothing)
        )
        test_parse(
            raw"\sum_{k=0}^n",
            (:underover,
                (:symbol, '∑'),
                (:group, 'k', (:spaced, (:symbol, '=')), (:digit, '0')),
                'n'
            )
        )
        test_parse(
            raw"\lim_x",
            (:underover,
                (:function, "lim"),
                'x',
                nothing
            )
        )
    end

    @testset "Square root" begin
        test_parse(raw"\sqrt{x}", (:sqrt, 'x'))
        test_parse(
            raw"\sqrt{abc}",
            (:sqrt, (:group, 'a', 'b', 'c'))
        )
    end

    @testset "Overline" begin
        test_parse(raw"\overline{x}", (:overline, 'x'))
        test_parse(
            raw"\overline{abc}",
            (:overline, (:group, 'a', 'b', 'c'))
        )
    end

    @testset "Space" begin
        test_parse(raw"\quad", (:space, 1))
        test_parse(raw"\qquad", (:space, 2))
        test_parse(raw"~", (:space, 0.33333))
    end

    @testset "Spaced symbol" begin
        test_parse(raw"=", (:spaced, (:symbol, '=')))
        test_parse(
            raw"\rightarrow",
            (:spaced, (:symbol, '→'))
        )
        # Hyphen must be replaced by a minus sign
        test_parse(raw"-", (:spaced, (:symbol, '−')))

        test_parse(raw"a-b $c-d$",
                   (:char, 'a'), (:char, '-'), (:char, 'b'),
                   (:char, ' '),
                   (:inline_math,
                    (:char, 'c'),
                    (:spaced, (:symbol, '−')),
                    (:char, 'd')))
    end

    @testset "Subscript and superscript" begin
        @test texparse(raw"a^2_3") == texparse(raw"a_3^2")
        @test texparse(raw"^7_b") == texparse(raw"{}^7_b")
    end

    @testset "Symbol" begin
        test_symbols = [
            ("ϕ", raw"\phi"),
            ("φ", raw"\varphi"),
            ("Φ", raw"\Phi"),
            # The following test symbols with multiple commands
            ("ε", raw"\varepsilon"),
            ("ε", raw"\upepsilon")
        ]

        for (char, sym) in test_symbols
            test_parse(sym, (:symbol, first(char)))
            @test texparse(char) == texparse(sym)
        end

        # Check interaction with decoration
        test_parse(
            raw"ω_k",
            (:decorated, (:symbol, 'ω'), 'k', nothing)
        )
    end
end
