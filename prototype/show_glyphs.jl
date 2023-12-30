using CairoMakie
using MathTeXEngine

offset = 8400
ncols = 30
nrows = 15

glyph_ids = [offset + j + (i -1)*ncols for i in 1:nrows, j in 1:ncols]
font = "assets/fonts/NewComputerModern/NewCMMath-Regular.otf"
fig = Figure(; size = (1800, 1000))

for ci in CartesianIndices(glyph_ids)
    gid = glyph_ids[ci]
    try
        Label(fig[ci[1], ci[2]], "$(Char(gid))" ; font)
    catch
        Label(fig[ci[1], ci[2]], " " ; font)
    end
end

fig