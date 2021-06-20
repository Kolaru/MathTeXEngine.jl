@testset "Fonts" begin
    @testset "Caching" begin
        for font in values(_default_fonts)
            @test load_font(font) === load_font(font)
        end
    end
end