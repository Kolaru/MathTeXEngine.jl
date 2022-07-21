using Pkg

Pkg.activate("prototype")

using MathTeXEngine
using CairoMakie

tex = L"\int dx \theta 2 x"
text(0, 0 ; text = tex, textsize=20)


elems = generate_tex_elements(tex)