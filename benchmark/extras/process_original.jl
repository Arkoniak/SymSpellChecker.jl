using DataFrames
using CSV

data = readlines(joinpath(@__DIR__, "original.txt"))
data

df = DataFrame(implementation = String[], max_edit = Int[], prefix_length = Int[],
    dict_name = String[], verbosity = String[], type = String[],
    res = Int[], min_val = Float64[], med_val = Float64[], avg_val = Float64[])

for s in data
    if startswith(s, "Precalculation")
        m = match(r"MaxEditDistance=([0-9]+) prefixLength=([0-9]+) dict=(.*)$", s)
        println("$(m[1])\t$(m[2])\t$(m[3])")
        global max_edit = parse(Int, m[1])
        global prefix_length = parse(Int, m[2])
        global dict_name = m[3]
    end

    # Lookup instance 1 results 0.000063ms/op verbosity=Closest query=exact
    if startswith(s, "Lookup")
        m = match(r"Lookup ([\w]*)\s*([\d\,]+)\s*results\s*([\d\.]+)ms/op\s*verbosity=([\w]*)\s*query=([\w\-]*)$", s)
        implementation = "CS$(m[1])"
        res = parse(Int, replace(m[2], ','=>""))
        avg_val = parse(Float64, m[3])
        @show m[3], parse(Float64, m[3])
        verbosity = lowercase(m[4])
        query = m[5]

        # pushing avg_val to other columns, which is not exactly correct
        push!(df, (implementation, max_edit, prefix_length, dict_name, verbosity, query, res,
            avg_val, avg_val, avg_val))
    end
end

CSV.write(joinpath(@__DIR__, "original_bench.csv"), df)

##################
# Sanity check

df2 = CSV.read(joinpath(@__DIR__, "original_bench.csv"))

df == df2   # true
