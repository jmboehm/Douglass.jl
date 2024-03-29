# douglass.jl

# Todo implement for first version:
#
# @gen is probably suffering from type instability
# @egen is still really crap. It should expect a type (e.g. `egen Float64 :x = ...`)

# Nice to have, but not necessary for first version:
# assert <condition>
# collapse (<statistic>) <varlist> ... , by(<varlist>)
# append using <df>

# WARNING:
# Douglass does not sanitize your input. If you run @gen(df, :x, destory_world()), 
# that's your responsibility. You've been warned.
#
# ANOTHER WARNING:
# There are some notable differences to how Stata behaves:
# - Variables in a DataFrame are denoted using symbols, e.g. ``:myvariable` as opposed to Stata's `myvariable`
# - Missing values are NOT considered greater than any real number. If you if-condition evaluates to a missing number (in julia), 
#   such as for example the condition `missing > 5`, then we will treat that like `false`. In other words, only if the condition
#   evaluates explicitly to `true`, or is automatically converted to `true`, the condition is considered satisfied. 
# - There is only one missing value, namely `missing`.
# - If `egen` does not have any nonmissing observations to work with, it returns `missing`, not zero (i.e. what the option `missing` does in Stata).
# - `egen` and `ereplace` operate on vectors of variables (in each group), whereas `gen` and `replace` operate on scalars. That means that in 
#   the former, you can use functions that take vectors as arguments, but if you do element-wise operations you have to broadcast these operations
#   (e.g. `bysort groupvar: egen :z = mean(:x)`, or `bysort groupvar: egen :z = :x .+ :y`). In `gen` and `replace`, you can use indexing, e.g. using
#   `bysort groupvar: gen :z = :x[_n] - :x[_n-1]`.
#__precompile__()
module Douglass

    using Reexport
    @reexport using DataFramesMeta
    using DataFrames, DataFramesMeta, Tables
    using MacroTools
    using REPL
    
    import DataFramesMeta: @with, @where

    # types
    include("Command.jl")

    include("setup.jl")
    include("interface.jl")

    include("parse.jl")

    include("commands/drop.jl")
    include("commands/keep.jl")
    include("commands/sort.jl")
    include("commands/generate.jl")
    include("commands/replace.jl")
    include("commands/rename.jl")
    include("commands/egen.jl")
    include("commands/erep.jl")
    # include("commands/egen2.jl")
    include("commands/merge.jl")
    include("commands/reshape.jl")
    include("commands/duplicates.jl")

    include("repl.jl")

    include("helper.jl")

    global active_df

    export @use, @d_str, set_active_df

end

