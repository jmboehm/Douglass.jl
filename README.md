# Douglass.jl

![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg) 
<!--![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)-->
<!--![Lifecycle](https://img.shields.io/badge/lifecycle-stable-green.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-retired-orange.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-archived-red.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-dormant-blue.svg) -->
[![Build Status](https://travis-ci.org/jmboehm/GLFixedEffectModels.jl.svg?branch=master)](https://travis-ci.org/jmboehm/Douglass.jl) [![Coverage Status](https://coveralls.io/repos/github/jmboehm/Douglass.jl/badge.svg?branch=master)](https://coveralls.io/github/jmboehm/Douglass.jl?branch=master)


Toolkit for doing data wrangling on Julia DataFrames. Loosely based off Stata's syntax.

## Examples

```julia
using Douglass, RDatasets
df = dataset("datasets", "iris")
# set the active DataFrame
Douglass.set_active_df(:df)

# create a variable `z` that is the sum of `SepalLength` and `SepalWidth`, for each row
d"gen :z = :SepalLength + :SepalWidth"
# replace `z` by the row index for the first 10 observations
d"replace :z = _n if _n <= 10"
# drop a variable
d"drop :z"
# construct the within-group mean for a subset of the observations
d"bysort :Species : egen :z = mean(:SepalLength) if :SepalWidth .> 3.0"
```

## Commands implemented

- `generate`, `replace`, `drop`, `keep`, `rename`, `sort`, `egen` (and an analogous version, `ereplace`), `reshape`, `merge`

## Notes

- Keep in mind that this is not Stata. [Here](differences-from-Stata.md) are some notable differences.

## Roadmap / Todo's

- In the medium term:
    * A custom REPL mode

-  In the long term:
    * If there's demand for it, one could make this extensible, so that other commands can be added in separate packages

## Misc

Douglass.jl is named in honour of the economic historian [Douglass North](https://en.wikipedia.org/wiki/Douglass_North).