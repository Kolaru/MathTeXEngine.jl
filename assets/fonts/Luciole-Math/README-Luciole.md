Luciole package
===============

## Description

This package provides four Unicode Math text fonts `Luciole-*.ttf’ and
a companion maths font `Luciole-Math.otf’.  
They have been developed explicitly for visually impaired people
and are the result of a collaboration between the Regional Technical Center
for Visual Impairment, the type-design studio typographies.fr and
the mathematician Daniel Flipo. The Luciole project received a grant from
the Swiss Ceres Foundation and the PEP69 association, and support from
the DIPHE laboratory at the Université Lumière Lyon 2 and the association
GUTenberg. 

## Contents

* Luciole-Regular.ttf, Luciole-Regular-Italic.ttf, Luciole-Bold.ttf and
  Luciole-BoldItalic.ttf  OpenType Text fonts
* Luciole-Math.otf        OpenType Math font
* luciole-math.sty        LaTeX style file for Luciole-Math.otf
* Luciole.fontspec        Defaults for Text fonts
* Luciole-Doc.pdf         Documentation in PDF format
* Luciole-Doc.ltx         Source of Luciole-Math.pdf
* unimath-luciole.pdf     Modified version of unimath-symbols.pdf
                          showing available Luciole-Math symbols compared
                          to other Maths fonts,
* unimath-luciole.ltx     Source of unimath-luciole.pdf
* README.md               (this file)

## Installation

This package `Luciole’ is meant to be installed automatically by TeXLive,
MikTeX, etc. Otherwise,  can be installed under TEXMFHOME or TEXMFLOCAL, f.i.
fonts in directory texmf-local/fonts/opentype/public/luciole/ and
luciole-math.sty, Luciole.fontspec in directory texmf-local/tex/latex/luciole/.  
Documentation files and their sources can go to directory
texmf-local/doc/fonts/public/luciole/

Don't forget to rebuild the file database (mktexlsr or so) if you install
under TEXMFLOCAL.

Finally, make the system font database aware of the Luciole fonts
(fontconfig under Linux).

## License

* The Text fonts `Luciole-*.ttf’ are licensed under the Creative Common CC-BY
Font License,
* The font `Luciole-Math.otf’ is licensed under the SIL Open Font License,
Version 1.1. This license is available with a FAQ at:
http://scripts.sil.org/OFL
* The other files are distributed under the terms of the LaTeX Project
Public License from CTAN archives in directory macros/latex/base/lppl.txt.
Either version 1.3c or, at your option, any later version.

## Changes

* First public version: 0.40

---
Copyright 2024-2025  Laurent Bourcellier, Jonathan Fabreguettes, Daniel Flipo.
