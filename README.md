# MathTeXEngine

This is a work in progress package aimed at providing a pure Julia engine for LaTeX math mode. It depends on the other work in progress and unregistered package [MathTeXParser](https://github.com/Kolaru/MathTeXParser.jl).

Ultimately the goal is to export only one function from this package that takes a LaTeX string as input and return a list of tuples `(TeXElement, position, scale)` where `TeXElement` is one of the following:

- `TeXChar(char, font)` a unicode character to be displayed in a specific font.
- `VLine(height, thickness)` a vertical line.
- `HLine(width, thickness)` an horizontal line.
- `Space(width)` a space (only present for debugging purpose).

This contains enough information to then draw everyting with any plotting package that can draw arbitrary glyph in arbitrary font. 

Currently, a prototype of a renderer using CairoMakie is available in `prototype.jl`. The rendering will later be moved outside of this package, but currently this is convenient for testing. Below is an example of the current output of `prototype.jl`.

![Example](example.png)
