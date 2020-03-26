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
            # execute, and copy it to another dataframe, 
            # otherwise we get copies of the group variables in there as well
            t2 = by($t, $varlist_by, my_f )
            $t[!,$(assigned_var)] = t2[!,$(assigned_var)]
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