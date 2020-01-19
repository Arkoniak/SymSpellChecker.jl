# Taken from: https://github.com/tkf/Transducers.jl/tree/master/benchmark
if lowercase(get(ENV, "CI", "false")) == "true"
    @info "Executing in CI. Instantiating benchmark environment..."
    using Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
end

using BenchmarkTools
const SUITE = BenchmarkGroup()
for file in sort([file for file in readdir(@__DIR__) if startswith(file, "bench_") && endswith(file, ".jl")])
    m = match(r"bench_[0-9]*(.*).jl", file)

    SUITE[m[1]] = include(file)
end
