# Differences between Douglass.jl and Stata

## General

- Keep in mind that Douglass.jl only takes your command, parses it, and calls the appropriate functions in DataFramesMeta.jl or DataFrames.jl. Hence, you are working with the types in Julia (`Int64`, `Float64`, etc.), and the results of your operations are the results of the operations in Julia. This applies, in particular, to the [behavior of `missing`](https://docs.julialang.org/en/v1/manual/missing/) and to the rules on [type conversion and promotion](https://docs.julialang.org/en/v1/manual/conversion-and-promotion/).
- Variables in the activate `DataFrame` are referenced using colons (`:`), e.g. `:myvariable`. If you do not use the colon, Douglass assumes that it's a variable in the current scope, e.g.
```julia
> x = 1.0
> d"gen :x = x"
```
creates a new variable that is being assigned the scalar `1.0` in every row.
- Macros: Stata's local and global macros are not supported. You can create strings in Julia and "interpolate" into the strings that you send to Douglass using a double dollar sign `$$`, e.g.
```julia
> name_of_new_var = "myname"
> d"gen :$$(name_of_new_var) = x"
```
The current implementation of this rests on Julia's `eval()`, however, and is therefore slow (so it's not real string interpolation!). If you know of a better solution, please let me know.
- You cannot use abbreviations for variables like in Stata (this is bad practice anyway), and in general you cannot use abbreviations for commands (exceptions to this are `gen` for `generate`, and `rep` for `replace`).


## Specific to certain commands

### `generate` and `replace`

- `generate` and `replace` operate on scalars of the current row, i.e. `:x` refers to `:x[_n]` where `_n` is the current row index (in fact, internally Douglass.jl is filling in those indices if you do not specify them explicitly).
- `generate` currently does not support Stata's explicit type declarations of the form `generate long :x = 1`. You can, however, use Julia functions to make sure that your assigned value are of a particular type, e.g. `generate :x = Float64(1)`.

### `egen` and `ereplace`

- Because it's a vector-valued operation, `_n` cannot be used.

### `reshape`

- Note that `reshape_wide` and `reshape_long` here, with a `_` instead of a whitespace.
- Unlike in Stata, `@` cannot be used as a whitecard.
- In `reshape_long`:
    * Unlike in Stata, the variable in j() is made to have type `Symbol` and is not automatically converted to `String` or numerical types.
    * Unlike in Stata, variables that are not listed in the arguments, `i`, or `j` are not part out the returned DataFrame. If you want to include them, list them as part of `i`.