# Douglass.jl

<!--![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)-->
<!--![Lifecycle](https://img.shields.io/badge/lifecycle-stable-green.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-retired-orange.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-archived-red.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-dormant-blue.svg) -->
![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg) [![Build Status](https://travis-ci.org/jmboehm/Douglass.jl.svg?branch=master)](https://travis-ci.org/jmboehm/Douglass.jl) [![Coverage Status](https://coveralls.io/repos/github/jmboehm/Douglass.jl/badge.svg?branch=master)](https://coveralls.io/github/jmboehm/Douglass.jl?branch=master)


Douglass.jl is a package for manipulating DataFrames in Julia using a syntax that is very similar to Stata.

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

## REPL mode

Press the backtick (`` ` ``) to switch between the normal Julia REPL and the Douglass REPL mode:

![REPL Screenshot](repl.png "Douglass REPL Screenshot")

## Notes

- Better documentation of the interface will come when the package is a bit more stable. In the meantime, the [Test script](https://github.com/jmboehm/Douglass.jl/blob/master/test/Douglass.jl) is probably the best introduction to the interface for those that know Stata.
- Keep in mind that this is not Stata. [Here](differences-from-Stata.md) are some notable differences.

## Roadmap / Todo's

- Implement more commands
- If other people find the package useful, it may be worth making the package extensible, so that other commands can be added in separate packages

## Misc

Douglass.jl is named in honour of the economic historian [Douglass North](https://en.wikipedia.org/wiki/Douglass_North).