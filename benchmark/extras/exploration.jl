using DataFrames
using CSV
using DataVoyager

dfcs = CSV.read(joinpath(@__DIR__, "original_bench.csv"))
dfjl = CSV.read(joinpath(@__DIR__, "bench.csv"))

insertcols!(dfjl, 1, :implementation => "Julia")

df = vcat(dfcs, dfjl)

v = Voyager(df)

v = Voyager(df[df.dict_name .== "30k", :])
