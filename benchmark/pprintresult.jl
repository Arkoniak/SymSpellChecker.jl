using PkgBenchmark
include("pprinthelper.jl")

if length(ARGS) == 1
    result = PkgBenchmark.readresults(ARGS[1])
elseif length(ARGS) == 0
    path = first(sort(readdir(joinpath(@__DIR__, "results")), rev = true))
    path = joinpath(@__DIR__, "results", path)
    result = PkgBenchmark.readresults(path)
end

displayresult(result)
