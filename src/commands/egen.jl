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

Syntax:
    `egenerate <var> = <expression> [if] <expression>`
    or 
    `bysort <varlist> (<varlist>): egenerate <var> = <expression> [if] <expression>`

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
`egen` is faster when combined with type declarations, e.g.
```julia
d"bysort mygroup (myindex): egen :x::Float64 = mean(:y)  if :z .> 1.0 "
```
If the type of the new column is not declared like that, `egen` will try to infer it by applying the right-hand side of the assignment
operation to the full DataFrame and taking the type of the resulting column. All columns that result from `egen` support `Missing`s.

Differences to Stata:
  - Type declarations are done via `d"egen :x::Float64 = :y .+ :z"`. Types are from Julia, of course (which means we can finally use 64-bit Integers!)
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
            egenerate <var> = <expression> [if <expression>]
        or 
            bysort <varlist> (<varlist>): egenerate <var> = <expression> [if <expression>]
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
            Douglass.@generate_byvec!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end
# version without `by` but with `if`
macro egenerate(t::Symbol, 
    by::Nothing, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@generate_byvec!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end


# this is a new implementation that separates the parsing and variable generation from the parsing
macro generate_byvec!(t::Symbol, 
    varlist_by::Union{Vector{Symbol}, Nothing}, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr,Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    
    # assert that `arguments` is an assignment
    (arguments.head == :(.=)) && error("`egen` expects a vector-wise assignment operation, e.g. `:x = :y + :z`. Do not broadcast the assignment operator.")
    (arguments.head == :(=)) || error("`egen` expects an assignment operation, e.g. :x = :y + :z")

    assigned_var_type::Symbol = :Any
    if isexpr(arguments.args[1])
        # this needs to take the form :x::Type
        ( arguments.args[1].head == Symbol("::") ) || error("Expected data type in assignment operation, e.g. `:x::Float64 = ...`")
        (size(arguments.args[1].args,1) == 2 ) || error("Expected data type in assignment operation, e.g. `:x::Float64 = ...`")
        assigned_var_qn = arguments.args[1].args[1]::QuoteNode
        assigned_var_type = arguments.args[1].args[2]::Symbol
    elseif isa(arguments.args[1], QuoteNode)
        assigned_var_qn = arguments.args[1]::QuoteNode
    end
    
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

    # println("transformation is a $(typeof(transformation)) with value $(transformation).")
    # println("assigned_var_qn is a $(typeof(assigned_var_qn)) with value $(assigned_var_qn).")

    if assigned_var_type == :Any
        # we don't know the type of the new column
        return esc(
            quote 
                # check variable is not present
                ($(assigned_var_qn) ∉ names($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")
                # determine the column type from doing the transformation on the DF
                assigned_var_type = eltype(@with($t,$(transformation)))
                # create the new column
                $t[!,$(assigned_var_qn)] = missings(assigned_var_type,size($t,1))
                # do the assignment
                Douglass.@transform_byvec2!($t, $varlist_by, $varlist_sort, $assigned_var_qn, $transformation, $filter)
            end
        )
    else
        # we know the type of the new column
        return esc(
            quote
                # check variable is not present
                ($(assigned_var_qn) ∉ names($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")
                # create the new column
                $t[!,$(assigned_var_qn)] = missings($(assigned_var_type),size($t,1))
                # do the assignment
                Douglass.@transform_byvec2!($t, $varlist_by, $varlist_sort, $assigned_var_qn, $transformation, $filter)
            end
        )
    end
end
# vector-wise transformation with `if` condition
macro transform_byvec2!(t::Symbol, 
    varlist_by::Vector{Symbol}, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Expr)
    
    return esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end

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
# vector-wise transformation without `if`
macro transform_byvec2!(t::Symbol, 
    varlist_by::Vector{Symbol}, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Nothing)
    
    return esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end

            # this is the function that maps every sub-df into its transformed df
            my_f = _df -> begin
                # define _N 
                _N = size(_df, 1)
                # do the transformation
                result = @with(_df, Douglass.helper_expand(_df,$(transformation)) )
                # make sure that assignment array is of same size
                (length(result) == size(_df,1)) || error("Assignment operation results in a vector of the wrong size.")
                _df[:,$(assigned_var_qn)] = result
                _df
            end
            $t = by($t, $varlist_by, my_f )
        end

    )
end
# version without groups but with if
macro transform_byvec2!(t::Symbol, 
    varlist_by::Nothing, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Expr)
    
    return esc(
        quote
            let _df = $t
                # sort, if we need to, (first by-variables, then sort-variables)
                if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                    sort!(_df, vcat($varlist_by, $varlist_sort))
                end

                _N = size(_df, 1)
                # construct a vector that tells us whether we should copy over the resulting value into the DF
                assignme = @with(_df, $filter)
                sdf = @where(_df, $filter)
                result = @with(sdf, Douglass.helper_expand(sdf,$(transformation)) )
                # make sure that assignment array is of same size
                (length(result) == sum(assignme)) || error("Assignment operation results in a vector of the wrong size.")
                __n::Int64 = 1
                for _n = 1:_N
                    if assignme[_n]
                        _df[_n,$(assigned_var_qn)] = result[__n]
                        __n+=1
                    end 
                end
            end
            $t
        end

    )
end
# version without `by` and `if`
macro transform_byvec2!(t::Symbol, 
    varlist_by::Nothing, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Nothing)
    return esc(
        quote
            let _df = $t
                # sort, if we need to, (first by-variables, then sort-variables)
                if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                    sort!(_df, vcat($varlist_by, $varlist_sort))
                end
                _N = size(_df, 1)
                # construct a vector that tells us whether we should copy over the resulting value into the DF
                result = @with(_df, Douglass.helper_expand(_df,$(transformation)) )
                # copy over manually
                # this is slower but preserves the type / makes automatic type conversion
                for _n = 1:_N
                    _df[_n,$(assigned_var_qn)] = result[_n]
                end
                # alternative: faster but we get type problems
                #_df[:,$(assigned_var_qn)] = result
            end
            $t
        end
    )
end


macro ereplace(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            ereplace <expression> [if] <expression>
        or 
            bysort <varlist> (<varlist>): ereplace <expression> [if] <expression>
    """)
end

# short form. This is a copy of the above for `erep`.
macro erep(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@ereplace($t, $by, $sort, $arguments, $filter, $use, $options)
        end
    )
end

macro ereplace(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@replace_byvec!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end

# implementation
macro replace_byvec!(t::Symbol, 
    varlist_by::Union{Vector{Symbol}, Nothing}, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr,Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    
    # assert that `arguments` is an assignment
    (arguments.head == :(.=)) && error("`erep` expects a vector-wise assignment operation, e.g. `:x = :y + :z`. Do not broadcast the assignment operator.")
    (arguments.head == :(=)) || error("`erep` expects an assignment operation, e.g. :x = :y + :z")

    # construct the QuoteNode
    if isexpr(arguments.args[1])
        # this needs to take the form :x::Type
        ( arguments.args[1].head == Symbol("::") ) && error("`ereplace` does not allow explicit type declarations`")
        assigned_var_qn = arguments.args[1].args[1]::QuoteNode
    elseif isa(arguments.args[1], QuoteNode)
        assigned_var_qn = arguments.args[1]::QuoteNode
    end
    
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

    return esc(
        quote
            # check variable is present
            ($(assigned_var_qn) ∈ names($t)) || error("Variable $($(assigned_var_qn)) not present in DataFrame.")
            # do the assignment
            Douglass.@transform_byvec2!($t, $varlist_by, $varlist_sort, $assigned_var_qn, $transformation, $filter)
        end
    )
end



# # old stuff

# # this macro is the generic macro for transformations of the sort:
# # bysort varlist (varlist): <assigned_var> = <expr> if <filter>
# # do not do any checks
# # arguments:
# #   fill::bool: if true, applies the statistic to all observations in the group, not just those for which `filter` expands to a statement that is `true`
# #
# # TODO: this is a really bad implementation. should have better way to get the output type
# macro transform_byvec!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Expr, options::Union{Dict{String,Any}, Nothing})
    
#     @show arguments
#     @show filter
    
#     # assert that `arguments` is an assignment
#     (arguments.head == :(.=)) && error("`egen` expects an vector-wise assignment operation, e.g. `:x = :y + :z`. Do not broadcast the assignment operator.")
#     (arguments.head == :(=)) || error("`egen` expects an assignment operation, e.g. :x = :y + :z")

#     # get the assigned var symbol (note that it's in a QuoteNode)
#     assigned_var::Symbol = arguments.args[1].value
#     # and the QuoteNode
#     assigned_var_qn::QuoteNode = arguments.args[1]
    
#     # if the RHS of the assignment expression is currently a symbol, make it an Expr
#     #transformation = (typeof(arguments.args[2]) == Symbol) ? Expr(arguments.args[2]) : arguments.args[2]
#     #if !isexpr(arguments.args[2])
#     # transformation::Expr = :( )
#     if isexpr(arguments.args[2])
#         transformation = arguments.args[2]
#     elseif isa(arguments.args[2], QuoteNode)
#         transformation = arguments.args[2]
#     else # if isa(arguments.args[2], Symbol)
#         transformation = arguments.args[2]
#     end

#     println("transformation is a $(typeof(transformation)) with value $(transformation).")
#     println("assigned_var_qn is a $(typeof(assigned_var_qn)) with value $(assigned_var_qn).")
    

#     return esc(
#         quote

#             # check variable is not present
#             ($(assigned_var_qn) ∉ names($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")

#             # sort, if we need to, (first by-variables, then sort-variables)
#             if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
#                 sort!($t, vcat($varlist_by, $varlist_sort))
#             end
#             #determine type of resulting column from the type of the first element
#             assigned_var_type = eltype(@with($t,$(transformation)))
#             $t[!,$(assigned_var_qn)] = missings(assigned_var_type,size($t,1))

#             # this is the function that maps every sub-df into its transformed df
#             my_f = _df -> begin
#                 # define _N 
#                 _N = size(_df, 1)
#                 # construct a vector that tells us whether we should copy over the resulting value into the DF
#                 assignme = @with(_df, $filter)
#                 #@show assignme
#                 sdf = @where(_df, $filter)
#                 result = @with(sdf, Douglass.helper_expand(sdf,$(transformation)) )
#                 # make sure that assignment array is of same size
#                 (length(result) == sum(assignme)) || error("Assignment operation results in a vector of the wrong size.")
#                 __n = 1
#                 for _n = 1:_N
#                     if assignme[_n]
#                         _df[_n,$(assigned_var_qn)] = result[__n]
#                         __n+=1
#                     end 
#                 end
#                 _df
#             end
#             $t = by($t, $varlist_by, my_f )
#         end

#     )
# end

# # with `by` but without `if`
# # this is pretty much a `DataFrames.by` combined with a `DataFramesMeta.@transform`
# macro transform_byvec!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Nothing, options::Union{Dict{String,Any}, Nothing})
#     # assert that `arguments` is an assignment
#     (arguments.head == :(.=)) && error("`egen` expects an vector-wise assignment operation, e.g. `:x = :y + :z`. Do not broadcast the assignment operator.")
#     (arguments.head == :(=)) || error("`egen` expects an assignment operation, e.g. :x = :y + :z")

#     # get the assigned var symbol (note that it's in a QuoteNode)
#     assigned_var::Symbol = arguments.args[1].value
#     # and the QuoteNode
#     assigned_var_qn::QuoteNode = arguments.args[1]
    
#     # if the RHS of the assignment expression is currently a symbol, make it an Expr
#     #transformation = (typeof(arguments.args[2]) == Symbol) ? Expr(arguments.args[2]) : arguments.args[2]
#     #if !isexpr(arguments.args[2])
#     # transformation::Expr = :( )
#     if isexpr(arguments.args[2])
#         transformation = arguments.args[2]
#     elseif isa(arguments.args[2], QuoteNode)
#         transformation = arguments.args[2]
#     else # if isa(arguments.args[2], Symbol)
#         transformation = arguments.args[2]
#     end

#     println("transformation is a $(typeof(transformation)) with value $(transformation).")
#     println("assigned_var_qn is a $(typeof(assigned_var_qn)) with value $(assigned_var_qn).")
    
#     return esc(
#         quote

#             # check variable is not present
#             ($(assigned_var_qn) ∉ names($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")

#             # sort, if we need to, (first by-variables, then sort-variables)
#             if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
#                 sort!($t, vcat($varlist_by, $varlist_sort))
#             end

#             # this is the function that maps every sub-df into its transformed df
#             my_f = _df -> begin
#                 # define _N 
#                 _N = size(_df, 1)
#                 #_df = @transform($t, $(assigned_var) = $(transformation))
#                 _df[!,$(assigned_var_qn)] = @with(_df, Douglass.helper_expand(_df,$(transformation)) )
#             end
#             $t = by($t, $varlist_by, my_f )
#         end

#     )
# end


# # this is the specific vesion that leads to generate's that are without `by`/`bysort`
# macro egenerate(t::Symbol, 
#     by::Nothing, 
#     sort::Union{Vector{Symbol}, Nothing}, 
#     arguments::Expr, 
#     filter::Union{Expr, Nothing}, 
#     use::Nothing, 
#     options::Nothing)
#     return esc(
#         quote
#             Douglass.@egenerate!($t, $sort, $arguments, $filter)
#         end
#     )
# end

# # version without `by`
# macro egenerate!(t::Symbol, 
#     varlist_sort::Union{Vector{Symbol}, Nothing}, 
#     arguments::Expr, 
#     filter::Union{Expr, Nothing})

#     # assert that `arguments` is an assignment
#     (arguments.head == :(=)) || error("`egenerate` expects an assignment operation, e.g. :x = :y + :z")

#     return esc(
#         quote 
#             Douglass.@transform!($t )
#         end
#     )

# end


# # this macro is the generic macro for transformations of the sort:
# # bysort varlist (varlist): <assigned_var> = <expr> if <filter>
# # do not do any checks
# # arguments:
# #   fill::bool: if true, applies the statistic to all observations in the group, not just those for which `filter` expands to a statement that is `true`
# macro transform!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, transformation::Expr, filter::Expr, arguments::Expr)
#     esc(
#         quote
#             # create arguments in a local scope
#             args = $arguments

#             if :fill ∈ args
#                 # assign to all rows in each group, even if $filter is not true
#                 out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
#                 $t[!,$assigned_var] = out[!,:x1]
#             else
#                 # assign only to rows where $filter is true
#                 $t[!,$(assigned_var)] = missings(Float64, size($t,1))
#                 assignme = @with($t,$(filter))
#                 out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
#                 @with $t begin
#                     for i = 1:size($t,1)
#                         if assignme[i]
#                             $(assigned_var)[i] = out[i,^(:x1)]
#                         end 
#                     end
#                 end
#             end
#             $t
#         end

#     )
# end

# # version without by
# macro transform!(t::Symbol, varlist_by::Nothing, varlist_sort::Expr, assigned_var, transformation::Expr, filter::Expr, arguments::Expr)
#     esc(
#         quote
#             # create arguments in a local scope
#             args = $arguments

#             if :fill ∈ args
#                 # assign to all rows in each group, even if $filter is not true
#                 out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
#                 $t[!,$assigned_var] = out[!,:x1]
#             else
#                 # assign only to rows where $filter is true
#                 $t[!,$(assigned_var)] = missings(Float64, size($t,1))
#                 assignme = @with($t,$(filter))
#                 out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
#                 @with $t begin
#                     for i = 1:size($t,1)
#                         if assignme[i]
#                             $(assigned_var)[i] = out[i,^(:x1)]
#                         end 
#                     end
#                 end
#             end
#             $t
#         end

#     )
# end