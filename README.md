# SymSpellChecker

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Arkoniak.github.io/SymSpell.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Arkoniak.github.io/SymSpell.jl/dev)
[![Build Status](https://travis-ci.com/Arkoniak/SymSpell.jl.svg?branch=master)](https://travis-ci.com/Arkoniak/SymSpell.jl)
[![Coveralls](https://coveralls.io/repos/github/Arkoniak/SymSpell.jl/badge.svg?branch=master)](https://coveralls.io/github/Arkoniak/SymSpell.jl?branch=master)

Julia port of [SymSpell](https://github.com/wolfgarbe/SymSpell), extremely fast spelling correction and fuzzy search algorithm.

## TL;DR
```julia
using SymSpellChecker

d = SymSpell()
push!(d, "hello")
push!(d, "world")

d["wrold"] = ["world"]
```

## Dictionary creation

Dictionaries can be created as follows

```julia
using SymSpellChecker

# Loading from file
d = SymSpell("assets/frequency_dictionary_en_30_000.txt")

# Manual update
d = SymSpell()
push!(d, "hello", 100)
push!(d, "world", 50)
```

Third term in `push!` function is the word frequency, which is used later in `lookup` to sort results from highest frequency to the lowest.

`SymSpell` constructor has following arguments

* **max_dictionary_edit_distance**: maximum allowed search distance. High value of this argument requires lots of memory. Default value is 2.
* **prefix_length**: prefix length used to generate candidates, higher values corresponds to higher memory requirements, but smaller search times. Default value is 5
* **count_threshold**: words with frequencies below this threshold wouldn't show in search results.

## Lookup procedure

Words search can be made as follows

```julia
lookup(d, "wrold") # [SuggestItem("world", 1, 50)]
```
Here `1` is a Damerau-Levenshtein distance between `world` and `wrold`, `50` is a word frequency in current dictionary.

One can extract only words from `lookup` result
```julia
term.(lookup(d, "wrold")) = ["world"]
```

There is more convenient form of `lookup` exists
```julia
d["wrold"] = ["world"]
```

Search arguments can be passed either in `lookup` function or set globally with the help of `set_options!(d::SymSpell; kwargs...)` command.
```julia
set_options!(d, include_unknown = true, verbosity = "closest")
d["wrold"] = ["wrold", "world"]

# this is equivalent to
term.(lookup(d, include_unknown = true, verbosity = "closest"))
```

Following arguments are supported

* **include_unknown**: whether include or not original word in results, if it falls under search criteria
* **ignore_token**: ignore words in lookup that contain token string or regexp.
* **transfer_casing**: when this option set to `true`, results will try to mimic casing of the original word, for example `d["Wrold"] = ["World"]`
* **max_edit_distance**: maximum allowed distance for search. By default equals to the `max_dictionary_edit_distance`
* **verbosity**: select type of search result. Three levels of verbosity exists
  * **"top"**: only single suggestion is returned, with lowest distance and highest frequency
  * **"closest"**: all words with lowest distance are returned
  * **"all"**: all words within given `max_edit_distance` are returned

## License

The SymSpellChecker.jl package is licensed under the MIT License. This package is based on [SymSpell](https://github.com/wolfgarbe/SymSpell) and it's [python adaptation](https://github.com/mammothb/symspellpy). Some parts of the code is based on [StringDistances.jl](https://github.com/matthieugomez/StringDistances.jl).
