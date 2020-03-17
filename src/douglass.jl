# douglass.jl

# Todo implement for first version:
# @bysort <varlist> (<varlist>) : <operation>
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

    # work in progress
    macro bysort!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, rest::Expr)
        esc(
            quote
                # make sure varlist_by and varlist_sort are present
                Douglass.@assert_vars_present($t, $varlist_by)
                Douglass.@assert_vars_present($t, $varlist_sort)

                # split
                gd = DataFrames.groupby($t, $varlist_by)
                for _df ∈ gd
                    $rest
                end
            end
        )
    end

    # this macro is the generic macro for transformations of the sort:
    # bysort varlist (varlist): <assigned_var> = <expr> if <filter>
    # do not do any checks
    macro transform!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, transformation::Expr, filter::Expr)
        esc(
            quote
                # @linq $t |>
                #     where($filter) |>
                #     sort($varlist_sort) |>
                #     by($varlist_by, $transformation)

                gd = groupby($t, $varlist_by)
                gd2 = map(_df -> @with(_df, Douglass.helper_expand(_df,$(transformation))), gd)
                out = DataFrame(gd2)
                $t[!,$assigned_var] = out[!,:x1]
                $t
            end

        )
    end

    # expand the argument x to the length of the df if it's not already a vector
    function helper_expand(df, x)
        size(x,1) == 1 ? repeat([x],size(df,1)) : x
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

