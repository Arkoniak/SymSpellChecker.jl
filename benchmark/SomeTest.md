# Benchmark Report for *SymSpell*

## Job Properties
* Time of benchmark: 19 Jan 2020 - 18:31
* Package commit: dirty
* Julia commit: 46ce4d
* Julia command flags: None
* Environment variables: None

## Results
Below is a table of this job's results, obtained by running the benchmarks.
The values listed in the `ID` column have the structure `[parent_group, child_group, ..., key]`, and can be used to
index into the BaseBenchmarks suite to retrieve the corresponding benchmarks.
The percentages accompanying time and memory values in the below table are noise tolerances. The "true"
time/memory value for a given benchmark is expected to fall within this percentage of the reported value.
An empty cell means that the value was zero.

| ID                              | time            | GC time | memory        | allocations |
|---------------------------------|----------------:|--------:|--------------:|------------:|
| `["lookup", "opcodes"]`         | 853.063 ns (5%) |         | 2.30 KiB (1%) |          29 |
| `["lookup", "transfer_casing"]` |   5.268 μs (5%) |         | 3.78 KiB (1%) |          53 |

## Benchmark Group List
Here's a list of all the benchmark groups executed by this job:

- `["lookup"]`

## Julia versioninfo
```
Julia Version 1.3.0
Commit 46ce4d7933 (2019-11-26 06:09 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
      Ubuntu 18.04.3 LTS
  uname: Linux 5.0.0-37-generic #40~18.04.1-Ubuntu SMP Thu Nov 14 12:06:39 UTC 2019 x86_64 x86_64
  CPU: Intel(R) Core(TM) i7-7700HQ CPU @ 2.80GHz: 
              speed         user         nice          sys         idle          irq
       #1  3439 MHz     381029 s       1937 s     123043 s   10513918 s          0 s
       #2  3445 MHz     382512 s       1338 s     136711 s    1591045 s          0 s
       #3  3498 MHz     395364 s       2836 s     100134 s    1596043 s          0 s
       #4  3439 MHz     393465 s       1747 s     120303 s    1597504 s          0 s
       #5  3349 MHz     388062 s        972 s     118830 s    1600886 s          0 s
       #6  3499 MHz     386586 s        914 s     116809 s    1604097 s          0 s
       #7  3094 MHz     356556 s       1343 s     133015 s    1602391 s          0 s
       #8  3491 MHz     388206 s       1012 s     120942 s    1587215 s          0 s
       
  Memory: 15.529525756835938 GB (4259.77734375 MB free)
  Uptime: 240445.0 sec
  Load Avg:  0.607421875  0.68212890625  0.65185546875
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-6.0.1 (ORCJIT, skylake)
```