using Documenter, GooSlicingFiles

include("src/assets/generate_obj.jl")

if :size_threshold in fieldnames(Documenter.HTML)
    size_th = (
        example_size_threshold = nothing,
        size_threshold = nothing,
    )
else
    size_th = ()
end

makedocs(
    clean = false,
    modules=[GooSlicingFiles],
    format=Documenter.HTML(;prettyurls = get(ENV, "CI", nothing) == "true",
                           size_th...,
                           assets = []),
    sitename="GooSlicingFiles",
    pages=[
        "Introduction" => "index.md",
        "Test Data" => "testdata.md",
        "API Reference" => "api.md",
    ]
)

deploydocs(
    repo="github.com/kimikage/GooSlicingFiles.jl.git",
    push_preview = true
)
