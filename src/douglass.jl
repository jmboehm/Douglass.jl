# douglass.jl

# Todo implement for first version:
# @duplicates_drop! <varlist>
# @merge! x:x <varlist> using <df2>
# @reshape! <type> <varlist> , i(<varlist>) j(<varlist>)
#
# Also need to make @gen and @replace <if>-able

# Nice to have, but not necessary for first version:
# @assert <condition>
# @collapse! (<statistic>) <varlist> ... , by(<varlist>)
# @append!
#
# It would be also really nice to support Stata's macros.

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
module Douglass

    using Tables, DataFrames, DataFramesMeta

    function gen(t, varname::Symbol, vec::Vector{T}) where {T}
        if varname ∈ names(t)
            error("Table already has a column with this name.")
        end
        if length(vec) != size(t,1)
            error("Vector is not of the same length as the table.")
        end
        t[!,varname] = deepcopy(vec)  # note that this makes a copy
    end

    # generate a variable named `varname` that contains vec
    # function gen(t, varname::Symbol, s::String)
    #     if varname ∈ names(t)
    #         error("Table already has a column with this name.")
    #     end
    #     x = @with(t, s)
    #     @show x
    #     t[!,varname] = x
    # end

    # rename the column `var` to `to`
    # uses DataFrames
    macro rename!(t::Symbol, var, to)
        esc(
            quote
                # check that we have a table
                !Tables.istable($t) && error("Object $(t) is not of a type that extends the Tables.jl interface.")

                # uses DataFrames
                rename!($t, $var => $to)
            end
        )
    end

    macro generate!(t,varname,ex,filter)
        esc(
            quote
                if $varname ∈ names($t)
                    error("Table already has a column with this name.")
                end
                local x = @with($t, ifelse.($filter, $ex , missing))
                # if we have a scalar, broadcast
                if size(x,1) == 1
                    $t[!,$varname] .= x
                else 
                    $t[!,$varname] = x
                end
            end
        )
    end

    macro generate_byrow!(t, varname, ex)

    end

    # @generate! without if-filter
    macro generate!(t,varname,ex)
        return esc( :( Douglass.@generate!($t,$varname,$ex,true) )  )
    end

    macro replace!(t,varname,ex)
        esc(
            quote
                if $varname ∉ names($t)
                    error("Variable $(varname) does not exist.")
                end
                local x = @with($t, $ex)
                # if we have a scalar, broadcast
                if size(x,1) == 1
                    $t[!,$varname] .= x
                else 
                    $t[!,$varname] = x
                end
            end
        )
    end

    # @drop_var! <varlist>
    macro drop_var!(t::Symbol,varlist::Expr)
        esc(
            quote
                # check that <varlist> is a Vector{Symbol}
                typeof($varlist) == Vector{Symbol} || error("Argument to drop! must 
                                                        be evaluating to a Vector{Symbol}. Type is $(typeof($varlist))")
                # check that all variables are present
                Douglass.@assert_vars_present($t, $varlist)
                # remove them all
                for v in $varlist
                    select!($t, Not(v))
                end
            end
        )
    end

    # @keep_var! <varlist>
    macro keep_var!(t::Symbol,varlist::Expr)
        esc(
            quote
                # check that <varlist> is a Vector{Symbol}
                typeof($varlist) == Vector{Symbol} || error("Argument to keep! must 
                                                        be evaluating to a Vector{Symbol}. Type is $(typeof($varlist))")
                # check that all variables are present
                Douglass.@assert_vars_present($t, $varlist)
                # keep them
                select!($t, $varlist)
            end
        )
    end

    # @drop_if! <filter>
    macro drop_if!(t::Symbol, filter::Expr)
        esc(
            quote
                # check that filter expands to a Vector of Union{Bool, Missing}
                Douglass.@assert_filter($t, $filter)
                # drop it like it's hot
                keepme = @with($t, $filter)
                filter!(r -> !keepme[DataFrames.row(r)] , $t)
            end
        )
    end

    # @keep_if! <filter>
    macro keep_if!(t::Symbol, filter::Expr)
        esc(
            quote
                # check that filter expands to a Vector of Union{Bool, Missing}
                Douglass.@assert_filter($t, $filter)
                # drop it like it's hot
                keepme = @with($t, $filter)
                filter!(r -> keepme[DataFrames.row(r)] , $t)
            end
        )
    end

    macro sort!(t::Symbol, varlist::Expr)
        esc(
            quote
                # check that all variables are present
                Douglass.@assert_vars_present($t, $varlist)
                sort!($t, $varlist)
            end
        )
    end

    # helper macro to make sure filter is valid
    macro assert_filter(t::Symbol, filter::Expr)
        esc(
            quote
                local x = @with($t, $filter)
                (typeof(x) <: BitArray{1}) || (typeof(x) <: Vector{Union{Missing,Bool}}) || error("filter is not a valid boolean vector.")
                true
            end
        )
    end

    # helper macro to make sure that expression evaluates to a Vector{Symbol}
    macro assert_varlist(t::Symbol, varlist::Expr)
        esc(
            quote
                typeof($varlist) == Vector{Symbol} || error("Argument must be evaluating to a Vector{Symbol}. Type is $(typeof($varlist))")
                true
            end
        )
    end
        
    # asserts that varlist evaluates to a Vector{Symbol} and checks that all Symbols are column names in t.
    macro assert_vars_present(t::Symbol, varlist::Expr)
        esc(
            quote
                # check that it's a varlist
                Douglass.@assert_varlist($t, $varlist)
                # check that they're present
                for v in $varlist
                    (v ∈ names($t)) || error("$(v) not a column name in $(t)")
                end
                true
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

    # this is a version that uses @byrow! Has the advantage that we don't need to use vectorized syntax, but not much else
    macro generate_byrow!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, assigned_var_type::Expr, transformation::Expr, filter::Expr, arguments::Expr)
        esc(
            quote
                # create arguments in a local scope
                args = $arguments

                # check variable is not present
                ($(assigned_var) ∉ names($t)) || error("Variable $(assigned_var) already present in DataFrame.")

                # this is the function that maps every sub-df into its transformed df
                my_f = _df -> @byrow! _df begin
                    @newcol $assigned_var::Array{Union{$assigned_var_type, Missing},1}
                    $(assigned_var) = $(transformation)
                end
                $t = by($t, $varlist_by, my_f )
                $t
            end
        )
    end

    # alternative version, doing stuff by row using @with (which has the advantage that we can use "[i]" syntax)
    # todo: 
    #   allow _n 
    #   assume that user means [i] if no index is shown (in transformation and filter)
    macro gen_byrow2!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, assigned_var_type, transformation::Expr, filter, arguments::Expr)
        esc(
            quote
                # create arguments in a local scope
                #args = $arguments

                # check that assigned_var_type is a valid type
                isa($(assigned_var_type),DataType) || error("assigned_var_type must be a DataType")

                # check variable is not present
                ($(assigned_var) ∉ names($t)) || error("Variable $(assigned_var) already present in DataFrame.")
                $t[!,$(assigned_var)] = missings($assigned_var_type,size($t,1))

                # sort, if we need to, (first by-variables, then sort-variables)
                if !isempty($(varlist_sort))
                    sort!($t, vcat($varlist_by, $varlist_sort))
                end

                # this is the function that maps every sub-df into its transformed df
                my_f = _df -> @with _df begin
                    # fill the new variable, row by row
                    for i in 1:size(_df,1)
                        if ($filter)  # if condition is not satisfied, leave with missing
                            $(assigned_var)[i] = $(transformation)
                        end
                    end
                    _df
                end
                $t = by($t, $varlist_by, my_f )
                $t
            end
        )
    end

    macro transform_byrow!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, transformation::Expr, filter::Expr, arguments::Expr)
        esc(
            quote
                # create arguments in a local scope
                args = $arguments

                # if variable is not present, needs to be created
                # if $(assigned_var) ∈ names($t)

                # this is the function that maps every sub-df into its transformed df
                my_f = _df -> @byrow! _df begin
                    @newcol x::Array{Float64}
                    :x = mean(:SepalLength)
                end
                by(df, [:sp], my_f )

                # if :fill ∈ args
                #     # assign to all rows in each group, even if $filter is not true
                #     out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
                #     $t[!,$assigned_var] = out[!,:x1]
                # else
                #     # assign only to rows where $filter is true
                #     $t[!,$(assigned_var)] = missings(Float64, size($t,1))
                #     assignme = @with($t,$(filter))
                #     out = by($t, $varlist_by, _df -> @with(@where(_df, $filter), Douglass.helper_expand(_df,$(transformation))))
                #     @with $t begin
                #         for i = 1:size($t,1)
                #             if assignme[i]
                #                 $(assigned_var)[i] = out[i,^(:x1)]
                #             end 
                #         end
                #     end
                # end
                $t
            end

        )
    end

    macro duplicates_drop!(t, varlist::Expr)
        esc(
            quote
                Douglass.@assert_vars_present($t, $varlist)
                unique!($t, $varlist)
            end
        )
    end
    
    # HELPER FUNCTIONS *********************************************************

    # expand the argument x to the length of the df if it's not already a vector
    # first generic version that supports size(_,1)
    function helper_expand(df, x)
        (ismissing(x) || size(x,1) == 1) ? repeat([x],size(df,1)) : x
    end
    # ... or to a length of l::Int64
    function helper_expand(l::Int64, x)
        (ismissing(x) || size(x,1) == 1) ? repeat([x],l) : x
    end

    # macro m(t::Symbol, e::Expr)
    #     esc(
    #         quote
    #             local x = @with($t, $e)
    #             size(t,1) == 1 ? repeat([$e],size(t,1))
    #         end
    #     )
    # end

    # macro helper_disallow_scalar(t::Symbol, e::Expr)
    #     esc(
    #         quote
    #             size(t,1) == 1 ? repeat($e .* ones(typeof) : e
    #         end
    #     )
    # end


    # macro assert_filter(t::Symbol, filter::Symbol)
    #     esc(
    #         quote
    #             error("filter is not a valid boolean vector. Please clarify the filter condition.")
    #         end
    #     )
    # end

    # # Stata prefix syntax
    # struct Prefix
    #     prefix::Symbol
    #     varlist::Vector{Symbol}

    # end

    # # Stata command format:
    # #  [prefix :] command [varlist] [=exp] [if] [in] [weight] [using filename] [, options]
    # # to this we add [frame] at the start, so that it becomes
    # # [frame] [prefix :] command [varlist] [=exp] [if] [in] [weight] [using filename] [, options]
    # struct Command
    #     frame::DataFrame
    #     prefix::Prefix
    #     command::Function
    #     varlist::Vector{Symbol}

    #     end
    # end

    # macro douglass(ex::Expr...)
    #     for i = 1:length(ex)
    #         @show ex[i]
    #     end
    # end


    # function egen(df::DataFrame,        # DF on which we operate
    #     byVarlist::Vector{Symbol},      # by variables
    #     sortVarlist::Vector{Symbol},    # sort variables
    #     newVarname::Symbol,             # newly generated symbol
    #     fct::Function,                  # function to use
    #     args::Vector{Symbol})           # argument list to the function

    # end

end

#@douglass bysort(var1,var2) frame(df) command(egen) args(arg1,arg2) if(condition) in(range) using(strfile) 

