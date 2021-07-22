function test_parse(input, args... ; broken=false)
    if broken
        @test_broken texparse(input) == manual_texexpr((:group, args...))
    else
        @test texparse(input) == manual_texexpr((:group, args...))
    end
end

@testset "Parser" begin
    @testset "Accent" begin
        test_parse(
            raw"\vec{a}",
            (:accent, raw"\vec", 'a'),
            broken=true
        )
        test_parse(
            raw"\dot{\vec{x}}",
            (:accent, raw"\dot", (:accent, raw"\vec", 'x')),
            broken=true
        )
    end

    @testset "Delimiter" begin
        test_parse(
            raw"\left( x \right)",
            (:delimited, '(', 'x', ')')
        )

        test_parse(
            raw"\left[ y \right)",
            (:delimited, '[', 'y', ')')
        )

        test_parse(
            raw"\left( a + b \right)",
            (:delimited,
                '(',
                (:group, 'a', (:spaced, '+'), 'b'),
                ')'
            )
        )

        @test_throws TeXParseError texparse(raw"\left( x")
        @test_throws TeXParseError texparse(raw"x \right)")

        # TODO Recursive delim
    end

    @testset "Fraction" begin
        test_parse(raw"\frac{1}{2}", (:frac, '1', '2'))
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
            (:function, "tan"), (:symbol, 'α', raw"\alpha")
        )
    end

    @testset "Group" begin
        test_parse(raw"{x}", 'x')
        test_parse(raw"{fgh}", (:group, 'f', 'g', 'h'))
        test_parse(
            raw"{a{b{cd}}}",
            (:group, 'a', (:group, 'b', (:group, 'c', 'd')))
        )

        @test_throws TeXParseError texparse(raw"{v")
        @test_throws TeXParseError texparse(raw"w}")
    end

    @testset "Integral" begin
        test_parse(
            raw"\int",
            (:integral, (:symbol, '∫', raw"\int"), nothing, nothing)
        )
        test_parse(
            raw"\int_a^b",
            (:overunder, (:symbol, '∫', raw"\int"), 'a', 'b')
        )
    end

    @testset "Overunder" begin
        test_parse(
            raw"\sum",
            (:underover, (:symbol, '∑', raw"\sum"), nothing, nothing)
        )
        test_parse(
            raw"\sum_{k=0}^n",
            (:underover,
                (:symbol, '∑', raw"\sum"),
                (:group, 'k', (:spaced, '='), '0'),
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

    @testset "Space" begin
        # Make sure they are all correct, because these commands contain
        # non letter characters
        for (command, width) in MathTeXEngine.spaces
            test_parse(command, (:space, width))
        end
    end

    @testset "Spaced symbol" begin
        test_parse(raw"=", (:spaced, '='))
        test_parse(
            raw"\rightarrow",
            (:spaced, (:symbol, '→', raw"\rightarrow"))
        )
        # Hyphen must be replaced by a minus sign
        test_parse(raw"-", (:spaced, '−'))
    end

    @testset "Subscript and superscript" begin
        @test texparse(raw"a^2_3") == texparse("a_3^2")
    end

    @testset "Symbol" begin
        for (char, sym) in zip(split("ϕ φ Φ"), split(raw"\phi \varphi \Phi"))
            test_parse(sym, (:symbol, first(char), sym))
            @test texparse(char) == texparse(sym)
        end

        # Check interaction with decoration
        test_parse(
            raw"ω_k",
            (:decorated, (:symbol, 'ω', "\\omega"), 'k', nothing)
        )
    end
end