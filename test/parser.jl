# TODO Adapt to single repo

using Test
using MathTeXParser

import MathTeXParser.manual_texexpr

test_parse(input, args...) = @test texparse(input) == manual_texexpr((:group, args...))

@testset "Accent" begin
    # test_parse(raw"\vec{a}", (:accent, raw"\vec", 'a'))
    # test_parse(raw"\dot{\vec{x}}", (:accent, raw"\dot", (:accent, raw"\vec", 'x')))
end

@testset "Decoration" begin
    @test texparse(raw"a^2_3") == texparse("a_3^2")
end

@testset "Command match full words" begin
    # Check braces are not added to the function name
    test_parse(raw"\sin{x}", (:function, "sin"), 'x')
end

@testset "Fraction" begin
    test_parse(raw"\frac{1}{2}", (:frac, '1', '2'))
end

@testset "Integral" begin
    test_parse(raw"\int", (:integral, (:symbol, '∫', raw"\int"), nothing, nothing))
    test_parse(raw"\int_a^b", (:overunder,
        (:symbol, '∫', raw"\int"), 'a', 'b'))
end

@testset "Overunder" begin
    test_parse(raw"\sum", (:underover, (:symbol, '∑', raw"\sum"), nothing, nothing))
    test_parse(raw"\sum_{k=0}^n", (:underover,
        (:symbol, '∑', raw"\sum"),
        (:group, 'k', (:spaced, (:symbol, '=', "=")), '0'),
        'n'))
end

@testset "Square root" begin
    test_parse(raw"\sqrt{x}", (:sqrt, 'x'))
end

@testset "Symbol" begin
    for (char, sym) in zip(split("ϕ φ Φ"), split(raw"\phi \varphi \Phi"))
        test_parse(sym, (:symbol, first(char), sym))
        @test texparse(char) == texparse(sym)
    end

    # Check interaction with decoration
    test_parse(raw"ω_k", (:decorated, (:symbol, 'ω', "\\omega"), 'k', nothing))
end