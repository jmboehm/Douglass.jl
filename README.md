# Douglass.jl

<!--![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)-->
<!--![Lifecycle](https://img.shields.io/badge/lifecycle-stable-green.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-retired-orange.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-archived-red.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-dormant-blue.svg) -->
![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg) ![example branch parameter](https://github.com/jmboehm/Douglass.jl/actions/workflows/ci.yml/badge.svg?branch=master) [![codecov.io](http://codecov.io/github/jmboehm/RegressionTables.jl/coverage.svg?branch=master)](http://codecov.io/github/jmboehm/Douglass.jl?branch=master)


Douglass.jl is a package for manipulating DataFrames in Julia using a syntax that is very similar to Stata.

**Note: Douglass.jl is in alpha, and may contain bugs. Please do try it out and report your experience. When using it in production, please check that the output is correct.**

## Installation

Douglass is not registered. To install, type `]` in the Julia command prompt, followed by
```
add https://github.com/jmboehm/Douglass.jl.git
```

## Examples

```julia
using Douglass, RDatasets, DataFrames, DataFramesMeta
df = dataset("datasets", "iris")
# set the active DataFrame
Douglass.set_active_df(:df)

# create a variable `z` that is the sum of `SepalLength` and `SepalWidth`, for each row
d"gen :z = :SepalLength + :SepalWidth"
# replace `z` by the row index for the first 10 observations
d"replace :z = _n if _n <= 10"
# drop a variable
d"drop :z"
# construct the within-group sum for a subset of the observations
d"bysort :Species : egen :z = sum(:SepalLength) if :SepalWidth .> 3.0"
```

## Commands implemented

- `generate` -- Creates a new variable and assigns the output from an expression to it.
- `replace` -- Recplaces the content of a variable, but does not change the type.
- `egenerate` (or `egen` for short) -- Creates a new variable. Operates on vectors.
- `ereplace` (or `erep` for short) -- Analogous to `egen`, replaces values of existing variables.
- `drop` -- Drops the specified observations (if used in conjunction with `if`) or variables (without `if`)
- `rename` -- Rename a variable
- `sort` -- Sort the rows activate `DataFrame` by the specified columns
- `reshape` -- Reshape the activate `DataFrame` between wide and long format (`reshape_long`, `reshape_wide`)
- `merge` -- Merge the active `DataFrame` with another one in the local scope (`merge_m1`, `merge_1m`, `merge_11`)
- `duplicates_drop` -- Delete duplicate rows, also by subset of columns

See the [commands documentation page](commands.md) for more details on syntax of these commands.

## REPL mode

Press the backtick (`` ` ``) to switch between the normal Julia REPL and the Douglass REPL mode:

![REPL Screenshot](repl.png "Douglass REPL Screenshot")

## Multiline and operations on a particular DataFrame

Douglass supports multiline input on the active dataframe:
```julia
d"""
gen :x = 5
gen :y = 6
"""
```

The `@douglass` macro allows subsequent operations to be performed on one particular DataFrame:
```julia
using RDatasets
iris = dataset("datasets", "iris")
Douglass.@douglass iris """
gen :x = :SepalWidth + :PetalWidth
gen :y = 42
"""
```

## Benchmarks

![benchmark](benchmark/benchmark.png "Benchmarks")

These benchmarks are made using a synthetic dataset with 1m observations, on my Macbook Pro (Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz, Julia 1.9.0, Stata/MP 17.0).

## Notes

- Better documentation of the interface will come when the package is a bit more stable. In the meantime, the [Test script](https://github.com/jmboehm/Douglass.jl/blob/master/test/Douglass.jl) is probably the best introduction to the interface for those that know Stata.
- Keep in mind that this is not Stata. [Here](differences-from-Stata.md) are some notable differences.

## Bug reports

Please file bug reports as [issues](https://github.com/jmboehm/Douglass.jl/issues).

## Roadmap / Todo's

- Implement more commands
- If other people find the package useful, it may be worth making the package extensible, so that other commands can be added in separate packages

If you find the package useful or the idea promising, please consider giving it a star (at the top of the page).

## Related Packages

- [Tidier.jl](https://github.com/TidierOrg/Tidier.jl) is a set of Julia packages that allow data manipulation and plotting using R's tidyverse syntax. If you like tidyverse syntax, this package may be for you.
- [StataCall.jl](https://github.com/jmboehm/StataCall.jl) is a package to call Stata from Julia
- [julia.ado](https://github.com/droodman/julia.ado) is a package to call Julia from Stata

## Misc

Douglass.jl is named in honour of the economic historian [Douglass North](https://en.wikipedia.org/wiki/Douglass_North).
