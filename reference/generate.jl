using Tar

include("references.jl")

begin
    @info "Generating reference images"
    reference_images = joinpath(@__DIR__, "reference_images")
    rm(reference_images, recursive = true, force = true)
    generate(reference_images)
    Tar.create(reference_images, "reference_images.tar")
end
