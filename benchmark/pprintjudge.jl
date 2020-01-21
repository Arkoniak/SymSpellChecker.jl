using PkgBenchmark
include("pprinthelper.jl")

if length(ARGS) == 2
    group_target = PkgBenchmark.readresults(ARGS[1])
    group_baseline = PkgBenchmark.readresults(ARGS[2])
else
    group_target = PkgBenchmark.readresults(joinpath(@__DIR__, "result-target.json"))
    group_baseline = PkgBenchmark.readresults(joinpath(@__DIR__, "result-baseline.json"))
end
judgement = judge(group_target, group_baseline)

displayresult(judgement)

printnewsection("Target result")
displayresult(group_target)

printnewsection("Baseline result")
displayresult(group_baseline)
