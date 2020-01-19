using PkgBenchmark
using Dates

benchmarkpkg(
    dirname(@__DIR__),
    BenchmarkConfig(
        env = Dict(
            "JULIA_NUM_THREADS" => "1",
            "OMP_NUM_THREADS" => "1",
        ),
    ),
    resultfile = joinpath(@__DIR__, "results", "$(Dates.format(now(), dateformat"yyyymmddTHHMMSS")).json"),
)
