using CairoMakie
using FileIO
using Git
using MathTeXEngine
using Tar
using Test
using TOML

include("references.jl")

function latest_refimages_tag()
    buff = IOBuffer()
    run(pipeline(git(["tag", "--list"]) ; stdout = buff))
    tags = split(String(take!(buff)))
    i = findlast(s -> (length(s) >= 9 && s[1:9] == "refimages"), tags)
    return tags[i]
end

function download_refimages(tag = latest_refimages_tag())
    url = "https://github.com/Kolaru/MathTeXEngine.jl/releases/download/$tag/reference_images.tar"
    images_tar = joinpath(@__DIR__, "reference_images.tar")
    images = joinpath(@__DIR__, "reference_images")
    if isfile(images_tar)
        if Bool(parse(Int, get(ENV, "REUSE_IMAGES_TAR", "0")))
            @info "$images_tar already exists, skipping download as requested"
        else
            rm(images_tar)
        end
    end
    !isfile(images_tar) && download(url, images_tar)
    isdir(images) && rm(images, recursive = true, force = true)
    Tar.extract(images_tar, images)
    return images
end

@testset "Reference images" begin
    @info "Reference test started"

    @info "Downloading reference images"
    reference_images = download_refimages()
    
    @info "Generating comparison images"
    comparison_images = joinpath(@__DIR__, "comparison_images")
    rm(comparison_images, recursive = true, force = true)
    generate(comparison_images)
    
    # Compare
    reference_comparison_images = joinpath(@__DIR__, "reference_comparison_images")
    rm(reference_comparison_images, recursive = true, force = true)
    path = mkpath(reference_comparison_images)

    @info "Comparing images"
    for group in keys(inputs)
        refimg = load(joinpath(reference_images, "$group.png"))
        img = load(joinpath(comparison_images, "$group.png"))

        if img != refimg
            @info "Saving the reference comparison for '$group'."
            fig = Figure()
            fig[1, 1] = Label(fig, "Reference", tellwidth=false)
            axref = fig[2, 1] = Axis(fig, aspect=DataAspect())
            image!(axref, rotr90(refimg))

            fig[1, 2] = Label(fig, "Current", tellwidth=false)
            axcurrent = fig[2, 2] = Axis(fig, aspect=DataAspect())
            image!(axcurrent, rotr90(img))

            save(joinpath(path, "$group.png"), fig)
        end
        @test img == refimg
    end
end
