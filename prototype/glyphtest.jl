using Pkg

Pkg.activate("prototype")

using MathTeXEngine
using CairoMakie

tex = L"\hbar \omega"
text(0, 0 ; text = tex, fontsize = 120)

elems = generate_tex_elements(tex)