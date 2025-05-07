@testset "TeXExpr" begin
    @testset "leafmap" begin
        ab = texparse(raw"a + b_a")
        xx = texparse(raw"x + b_x")

        @test xx == MathTeXEngine.leafmap(ab) do leaf
            leaf.args[1] == 'a' && return TeXExpr(:char, 'x')
            return leaf
        end
    end
end
