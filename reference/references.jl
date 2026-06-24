using CairoMakie
using MathTeXEngine
using LaTeXStrings

include("data/basics.jl")
include("data/spacing.jl")
include("data/bold_symbols.jl")

with_font(font_name, expr) = latexstring("\\fontfamily{$font_name}$expr")

const REFERENCES = Dict(
    "basics" => BASICS,
    "bold_symbols" => BOLD_SYMBOLS,
    "spacing" => SPACING
)

const SUPPORTED_FONTS = [
    "NewComputerModern",
    "TeXGyreHeros",
    "TeXGyrePagella",
    "LucioleMath",
]

function generate(destination_folder, references = REFERENCES, fonts = SUPPORTED_FONTS)
    @info "Generating images in folder $destination_folder"

    path = mkpath(destination_folder)
    failures = Dict()
    for (group, data) in references
        if data isa AbstractDict
            generate(joinpath(destination_folder, group), data)
        else
            fig, fails = reference_figure(data, fonts)

            if !isempty(fails)
                failures[group] = fails
            end

            save(joinpath(path, "$group.png"), fig, px_per_unit = 3)
        end
    end

    return failures
end

function reference_figure(exprs, fonts = SUPPORTED_FONTS)
    fig = Figure()
    failures = Dict()
    for (j, font) in enumerate(fonts)
        Label(fig[0, j], font)
        for (i, expr) in enumerate(exprs)
            try
                Label(fig[i, j], with_font(font, expr))
            catch e
                failures[expr] = e
            end
        end
    end
    resize_to_layout!(fig)
    return fig, failures
end
