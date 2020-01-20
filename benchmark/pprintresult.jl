using PkgBenchmark
include("pprinthelper.jl")
result = PkgBenchmark.readresults(ARGS[1])
displayresult(result)
