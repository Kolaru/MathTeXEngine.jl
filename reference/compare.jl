using CairoMakie
using FileIO
using Git
using MathTeXEngine
using Test

include("references.jl")

const git = Git.git()

begin
    readchomp(`$git fetch`)
    master_id = readchomp(`$git rev-parse --short master`)
    current_id = readchomp(`$git rev-parse --short HEAD`)
    is_clean = isempty(readchomp(`$git status -s`))
    current_branch = readchomp(`$git rev-parse --abbrev-ref HEAD`)

    @info "Reference test started on branch $current_branch"

    if !is_clean
        @warn "Using dirty commit for comparison"
        current_id *= "-dirty"
    end

    rm("reference/$current_id", recursive = true, force = true)
    generate("reference/$current_id")

    if current_branch == "master"
        @info "Reference test started on master branch, nothing to compare"
        return
    end

    if !isdir("reference/$master_id")
        @warn "No reference available for master commit $master_id, aborting"
        @test_broken false
        return
    end

    @info "Comparing reference on master $master_id with current commit $current_id on branch $current_branch"

    # Compare
    rm("reference/comparisons", recursive = true, force = true)
    path = mkpath("reference/comparisons")

    for group in keys(inputs)
        refimg = load("reference/$master_id/$group.png")
        img = load("reference/$current_id/$group.png")

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
