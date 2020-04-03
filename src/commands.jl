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
    
# asserts that varlist::Expr evaluates to a Vector{Symbol} and checks that all Symbols are column names in t.
macro assert_vars_present(t::Symbol, varlist::Expr)
    esc(
        quote
            # check that it's a varlist
            Douglass.@assert_varlist($t, $varlist)
            # check that they're present
            for v in $varlist
                (v ∈ names($t)) || error("$(v) not a column name in the active DataFrame")
            end
            true
        end
    )
end

# Checks that all Symbols are column names in t.
macro assert_vars_present(t::Symbol, varlist::Vector{Symbol})
    esc(
        quote
            # check that they're present
            ($varlist ⊆ names($t)) || error("$($varlist) is not a subset of the columns in the active DataFrame")
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

# merge <type> <keys> using <rhs> , <options>
# Note: this could also be a function, really
macro merge!(t::Symbol, type, keys, rhs, options)
    esc(
        quote
            # make sure keys are present in both master and using
            assert_vars_present($t, $keys)
            assert_vars_present($rhs, $keys)

            # outer = 1:1 or m:1 

            # outer with lhs and rhs switched: 1:m

            # whenever the merge has a '1' in Stata, the keys must be uniquely identifying observations
            # this needs to be checked
            if ($type == :one_to_one) || ($type == :m_to_one)
                # check that we are restraining things correctly
                ($type == :one_to_one) && (Douglass.unique_obs($t, $keys) || error("Keys are not uniquely identifying observations in master DataFrame."))
                Douglass.unique_obs($rhs, $keys) || error("Keys are not uniquely identifying observations in using DataFrame.")
                # do the merge
                join($t, $rhs, on = $keys, kind = :outer)
            elseif ($type == :one_to_m)
                Douglass.unique_obs($t, $keys) || error("Keys are not uniquely identifying observations in master DataFrame.")
                # do the merge
                join($rhs, $t, on = $keys, kind = :outer)
            elseif ($type == :m_to_m)
                error("m:m mergers are not allowed.")
            else
                error("Invalid merge type.")
            end
        end
    )
end

# high-level macros:

macro egen()
    println("we are in egen!")
end
