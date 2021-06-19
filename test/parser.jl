import MathTeXEngine: manual_texexpr, texparse

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
            broken=true)
        test_parse(
            raw"\dot{\vec{x}}",
            (:accent, raw"\dot", (:accent, raw"\vec", 'x')),
            broken=true)
    end

    @testset "Delimiter" begin
        test_parse(
            raw"\left( x \right)",
            (:delimited, '(', 'x', ')')
        )

        test_parse(
            raw"\left( a + b \right)",
            (:delimited,
                '(',
                (:group,
                    'a',
                    (:spaced, '+'),
                    'b'),
                ')'
            )
        )

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
    end

    @testset "Group" begin
        test_parse("{x}", 'x')
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
    end

    @testset "Square root" begin
        test_parse(raw"\sqrt{x}", (:sqrt, 'x'))
    end

    @testset "Spaced symbol" begin
        test_parse(raw"=", (:spaced, '='))
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
            (:decorated, (:symbol, 'ω', "\\omega"), 'k', nothing))
    end
end