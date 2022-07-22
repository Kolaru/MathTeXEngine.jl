@testset "Fonts" begin
    @testset "Caching" begin
        for font in values(_new_computer_modern_fonts)
            @test load_font(font) === load_font(font)
        end
    end
end