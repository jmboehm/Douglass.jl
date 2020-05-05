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

- `generate` -- Creates a new variable and assigns the output from an expression to it.
```
[bysort <varlist> (<varlist>):] generate <expression> [if <expression>]
```
The type of the variable is set to be what the expression evaluates to (and allows `missing`). `generate` operates row-by-row, so you can use `_n` to denote the current row index and do not need to broadcast operators.
- `replace` -- Recplaces the content of a variable, but does not change the type.
```
[bysort <varlist> (<varlist>):] replace <expression> [if <expression>]
```
`replace` works like `generate` in that it operates row-by-row.
- `egenerate` (or `egen` for short) -- Creates a new variable, operates on vectors
```
[bysort <varlist> (<varlist>):] egenerate <var> = <expression> [if <expression>]
```
The key difference between `generate` and `egen` is that the latter operates on vectors, e.g. you can do `by :group: egen :mymean = Statistics.mean(:var)`. That means that operations on scalars need to be broadcast (Julia's `.` syntax), e.g. `egen :mysum = :a .+ :b`.

`egen` tries to determine the new variable's type by evaluating the expression. Types can also be set explicitly, and this is currently faster: `egen :mysum::Float64 = mean(:var)`.

There is also an analogous version `ereplace` (or `erep` for short) that opera
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