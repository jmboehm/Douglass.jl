#
# `egenerate` (or short `egen`) and `ereplace`/`erep`
#
# Creates a new variable in the DataFrame. Operates by vector for both the assigned expression, and the
# filter condition, e.g. :var refers to the whole (filtered) column in the DataFrame (or in the group if
# used in conjunction with `by`/`bysort`). Operators need use broadcasting if they should operate on scalars.
# Examples:
# ```julia
# d"egen :x = mean(:y)"
# d"egen :x = :y .+ :z"
# d"egen :x = :y  if :z .> 1.0 "
# d"bysort mygroup (myindex): egen :x = mean(:y)  if :z .> 1.0 "
# ```
# 
# Notes:
#   - Because it's a vector-valued operation, `_n` cannot be used.
#
#
# this is the general form of the command

"""
`egenerate` (or `egen`)

Creates a new variable in the DataFrame. Operates by vector for both the assigned expression, and the
filter condition, e.g. :var refers to the whole (filtered) column in the DataFrame (or in the group if
used in conjunction with `by`/`bysort`). Operators need use broadcasting if they should operate on scalars.
Examples:
```julia
d"egen :x = mean(:y)"
d"egen :x = :y .+ :z"
d"egen :x = :y  if :z .> 1.0 "
d"bysort mygroup (myindex): egen :x = mean(:y)  if :z .> 1.0 "
```

Differences to Stata:
  - 

### Arguments
* `rr::FixedEffectModel...` are the `FixedEffectModel`s from `FixedEffectModels.jl` that should be printed. Only required argument.
* `regressors` is a `Vector` of regressor names (`String`s) that should be shown, in that order. Defaults to an empty vector, in which case all regressors will be shown.
* `fixedeffects` is a `Vector` of FE names (`String`s) that should be shown, in that order. Defaults to an empty vector, in which case all FE's will be shown. Note that the string needs to match the display label exactly, otherwise it will not be shown.
* `labels` is a `Dict` that contains displayed labels for variables (`String`s) and other text in the table. If no label for a variable is found, it default to variable names. See documentation for special values.
* `estimformat` is a `String` that describes the format of the estimate. Defaults to "%0.3f".
* `estim_decoration` is a `Function` that takes the formatted string and the p-value, and applies decorations (such as the beloved stars). Defaults to (* p<0.05, ** p<0.01, *** p<0.001).
* `statisticformat` is a `String` that describes the format of the number below the estimate (se/t). Defaults to "%0.3f".
* `below_statistic` is a `Symbol` that describes a statistic that should be shown below each point estimate. Recognized values are `:blank`, `:se`, and `:tstat`. Defaults to `:se`.
* `below_decoration` is a `Function` that takes the formatted statistic string, and applies a decorations. Defaults to round parentheses.
* `regression_statistics` is a `Vector` of `Symbol`s that describe statistics to be shown at the bottom of the table. Recognized symbols are `:nobs`, `:r2`, `:adjr2`, `:r2_within`, `:f`, `:p`, `:f_kp`, `:p_kp`, and `:dof`. Defaults to `[:nobs, :r2]`.
* `number_regressions` is a `Bool` that governs whether regressions should be numbered. Defaults to `true`.
* `number_regressions_decoration` is a `Function` that governs the decorations to the regression numbers. Defaults to `s -> "(\$s)"`.
* `print_fe_section` is a `Bool` that governs whether a section on fixed effects should be shown. Defaults to `true`.
* `print_estimator_section`  is a `Bool` that governs whether to print a section on which estimator (OLS/IV/NL) is used. Defaults to `true`.
* `standardize_coef` is a `Bool` that governs whether the table should show standardized coefficients. Note that this only works with `TableRegressionModel`s, and that only coefficient estimates and the `below_statistic` are being standardized (i.e. the R^2 etc still pertain to the non-standardized regression).
* `out_buffer` is an `IOBuffer` that the output gets sent to (unless an output file is specified, in which case the output is only sent to the file).
* `renderSettings::RenderSettings` is a `RenderSettings` composite type that governs how the table should be rendered. Standard supported types are ASCII (via `asciiOutput(outfile::String)`) and LaTeX (via `latexOutput(outfile::String)`). If no argument to these two functions are given, the output is sent to STDOUT. Defaults to ASCII with STDOUT.
* `transform_labels` is a `Function` that is used to transform labels. It takes the `String` to be transformed as an argument. See `README.md` for an example.
### Details
A typical use is to pass a number of `FixedEffectModel`s to the function, along with a `RenderSettings` object.
"""
macro egenerate(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            egenerate <expression> [if] <expression>
        or 
            bysort <varlist> (<varlist>): egenerate <expression> [if] <expression>
    """)
end

# short form. This is a copy of the above for `gen`.
macro egen(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@egenerate($t, $by, $sort, $arguments, $filter, $use, $options)
        end
    )
end

macro egenerate(t::Symbol, 
    by::Vector{Symbol}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@transform_byvec!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end

# this macro is the generic macro for transformations of the sort:
# bysort varlist (varlist): <assigned_var> = <expr> if <filter>
# do not do any checks
# arguments:
#   fill::bool: if true, applies the statistic to all observations in the group, not just those for which `filter` expands to a statement that is `true`
#
# TODO: this is a really bad implementation. should have better way to get the output type
macro transform_byvec!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Expr, options::Union{Dict{String,Any}, Nothing})
    
    @show arguments
    @show filter
    
    # assert that `arguments` is an assignment
    (arguments.head == :(.=)) && error("`egen` expects an vector-wise assignment operation, e.g. `:x = :y + :z`. Do not broadcast the assignment operator.")
    (arguments.head == :(=)) || error("`egen` expects an assignment operation, e.g. :x = :y + :z")

    # get the assigned var symbol (note that it's in a QuoteNode)
    assigned_var::Symbol = arguments.args[1].value
    # and the QuoteNode
    assigned_var_qn::QuoteNode = arguments.args[1]
    
    # if the RHS of the assignment expression is currently a symbol, make it an Expr
    #transformation = (typeof(arguments.args[2]) == Symbol) ? Expr(arguments.args[2]) : arguments.args[2]
    #if !isexpr(arguments.args[2])
    # transformation::Expr = :( )
    if isexpr(arguments.args[2])
        transformation = arguments.args[2]
    elseif isa(arguments.args[2], QuoteNode)
        transformation = arguments.args[2]
    else # if isa(arguments.args[2], Symbol)
        transformation = arguments.args[2]
    end

    println("transformation is a $(typeof(transformation)) with value $(transformation).")
    println("assigned_var_qn is a $(typeof(assigned_var_qn)) with value $(assigned_var_qn).")
    

    return esc(
        quote

            # check variable is not present
            ($(assigned_var_qn) ∉ names($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")

            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end
            #determine type of resulting column from the type of the first element
            assigned_var_type = eltype(@with($t,$(transformation)))
            $t[!,$(assigned_var_qn)] = missings(assigned_var_type,size($t,1))

            # this is the function that maps every sub-df into its transformed df
            my_f = _df -> begin
                # define _N 
                _N = size(_df, 1)
                # construct a vector that tells us whether we should copy over the resulting value into the DF
                assignme = @with(_df, $filter)
                #@show assignme
                sdf = @where(_df, $filter)
                result = @with(sdf, Douglass.helper_expand(sdf,$(transformation)) )
                # make sure that assignment array is of same size
                (length(result) == sum(assignme)) || error("Assignment operation results in a vector of the wrong size.")
                __n = 1
                for _n = 1:_N
                    if assignme[_n]
                        _df[_n,$(assigned_var_qn)] = result[__n]
                        __n+=1
                    end 
                end
                _df
            end
            $t = by($t, $varlist_by, my_f )
        end

    )
end

# with `by` but without `if`
# this is pretty much a `DataFrames.by` combined with a `DataFramesMeta.@transform`
macro transform_byvec!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Nothing, options::Union{Dict{String,Any}, Nothing})
    # assert that `arguments` is an assignment
    (arguments.head == :(.=)) && error("`egen` expects an vector-wise assignment operation, e.g. `:x = :y + :z`. Do not broadcast the assignment operator.")
    (arguments.head == :(=)) || error("`egen` expects an assignment operation, e.g. :x = :y + :z")

    # get the assigned var symbol (note that it's in a QuoteNode)
    assigned_var::Symbol = arguments.args[1].value
    # and the QuoteNode
    assigned_var_qn::QuoteNode = arguments.args[1]
    
    # if the RHS of the assignment expression is currently a symbol, make it an Expr
    #transformation = (typeof(arguments.args[2]) == Symbol) ? Expr(arguments.args[2]) : arguments.args[2]
    #if !isexpr(arguments.args[2])
    # transformation::Expr = :( )
    if isexpr(arguments.args[2])
        transformation = arguments.args[2]
    elseif isa(arguments.args[2], QuoteNode)
        transformation = arguments.args[2]
    else # if isa(arguments.args[2], Symbol)
        transformation = arguments.args[2]
    end

    println("transformation is a $(typeof(transformation)) with value $(transformation).")
    println("assigned_var_qn is a $(typeof(assigned_var_qn)) with value $(assigned_var_qn).")
    
    return esc(
        quote

            # check variable is not present
            ($(assigned_var_qn) ∉ names($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")

            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end

            # this is the function that maps every sub-df into its transformed df
            my_f = _df -> begin
                # define _N 
                _N = size(_df, 1)
                #_df = @transform($t, $(assigned_var) = $(transformation))
                _df[!,$(assigned_var_qn)] = @with(_df, Douglass.helper_expand(_df,$(transformation)) )
            end
            $t = by($t, $varlist_by, my_f )
        end

    )
end


# this is the specific vesion that leads to generate's that are without `by`/`bysort`
macro egenerate(t::Symbol, 
    by::Nothing, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Nothing)
    return esc(
        quote
            Douglass.@egenerate!($t, $sort, $arguments, $filter)
        end
    )
end

# version without `by`
macro egenerate!(t::Symbol, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing})

    # assert that `arguments` is an assignment
    (arguments.head == :(=)) || error("`egenerate` expects an assignment operation, e.g. :x = :y + :z")

    return esc(
        quote 
            Douglass.@transform!($t )
        end
    )

end


# this macro is the generic macro for transformations of the sort:
# bysort varlist (varlist): <assigned_var> = <expr> if <filter>
# do not do any checks
# arguments:
#   fill::bool: if true, applies the statistic to all observations in the group, not just those for which `filter` expands to a statement that is `true`
macro transform!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, transformation::Expr, filter::Expr, arguments::Expr)
    esc(
        quote
            # create arguments in a local scope
            args = $arguments

            if :fill ∈ args
                # assign to all rows in each group, even if $filter is not true
                out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
                $t[!,$assigned_var] = out[!,:x1]
            else
                # assign only to rows where $filter is true
                $t[!,$(assigned_var)] = missings(Float64, size($t,1))
                assignme = @with($t,$(filter))
                out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
                @with $t begin
                    for i = 1:size($t,1)
                        if assignme[i]
                            $(assigned_var)[i] = out[i,^(:x1)]
                        end 
                    end
                end
            end
            $t
        end

    )
end

# version without by
macro transform!(t::Symbol, varlist_by::Nothing, varlist_sort::Expr, assigned_var, transformation::Expr, filter::Expr, arguments::Expr)
    esc(
        quote
            # create arguments in a local scope
            args = $arguments

            if :fill ∈ args
                # assign to all rows in each group, even if $filter is not true
                out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
                $t[!,$assigned_var] = out[!,:x1]
            else
                # assign only to rows where $filter is true
                $t[!,$(assigned_var)] = missings(Float64, size($t,1))
                assignme = @with($t,$(filter))
                out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
                @with $t begin
                    for i = 1:size($t,1)
                        if assignme[i]
                            $(assigned_var)[i] = out[i,^(:x1)]
                        end 
                    end
                end
            end
            $t
        end

    )
end