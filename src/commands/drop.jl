# drop
#
# TODO: support _n and non-broadcast operators
#
# this is the general form of the command
# let it fail with an error, because we don't allow all these blocks
macro drop(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Expr, Nothing})
    error("""\n
        The syntax is:
            drop <varlist>
        or
            drop if <condition>
    """)
end

# this is `drop <varlist>`
macro drop(t::Symbol, by::Nothing, sort::Nothing, arguments::Union{Vector{Symbol},Expr}, filter::Nothing, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@drop_var!($t, $arguments)
        end
    )
end

# this is `drop if <condition>`
macro drop(t::Symbol, by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Nothing, 
    filter::Expr, 
    use::Nothing, 
    options::Nothing)
    return esc(
        quote 
            Douglass.@drop_if!($t, $by, $sort, $arguments, $filter, $use, $options)
        end
    )
end

# @drop_var! <varlist>
# TODO: check whether it would be faster to drop all in one go
macro drop_var!(t::Symbol, varlist::Vector{Symbol})
    esc(
        quote
            # check that all variables are present
            Douglass.@assert_vars_present($t, $varlist)
            # remove them all
            for v in $varlist
                select!($t, Not(v))
            end
            $t
        end
    )
end

# @drop_var! <varlist>
macro drop_var!(t::Symbol, varlist::Expr)
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
            $t
        end
    )
end

# @drop_if! <filter>
# This is the vector-valued function
# macro drop_if!(t::Symbol, filter::Expr)
#     esc(
#         quote
#             # check that filter expands to a Vector of Union{Bool, Missing}
#             Douglass.@assert_filter($t, $filter)
#             # drop it like it's hot
#             keepme = Douglass.@with($t, $filter)
#             filter!(r -> !keepme[DataFrames.row(r)] , $t)
#         end
#     )
# end

# version with `by`
# this effectively creates a new dummy variable by group and drops if it's 1
macro drop_if!(t::Symbol, varlist_by::Vector{Symbol}, 
    varlist_sort::Union{Vector{Symbol}, Nothing},
    arguments::Nothing,  
    filter::Expr,
    use::Nothing, 
    options::Union{Expr, Nothing})

    # replace non-indexed variables with _n
    Douglass.ref_quotenodes!(filter)

    assigned_var = gensym()
    assigned_var_qn = QuoteNode(assigned_var)

    return esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, $varlist_sort)
            end

            #determine type of resulting column from the type of the first element
            $t[!,$(assigned_var_qn)] = trues(size($t,1))

            # this is the function that maps every sub-df into its transformed df
            my_f = _df -> Douglass.@with _df begin
                # define _N 
                _N = size(_df, 1)
                # fill the new variable, row by row
                for _n in 1:size(_df,1)
                    if (isnothing($filter) ? false : $filter)  # if condition is not satisfied, leave with missing
                        $(assigned_var_qn)[_n] = false
                    end
                end
                _df
            end
            t2 = combine(my_f, groupby($t,$varlist_by, sort=false, skipmissing = false ))
            filter!(r -> t2[DataFrames.row(r),$(assigned_var_qn)] , $t)
            select!($t, Not($(assigned_var_qn)))
        end
    )
end

# version without `by`
macro drop_if!(t::Symbol, by::Nothing, 
    varlist_sort::Union{Vector{Symbol}, Nothing},  
    arguments::Nothing,  
    filter::Expr,
    use::Nothing, 
    options::Union{Expr, Nothing})

    # replace non-indexed variables with _n
    Douglass.ref_quotenodes!(filter)

    return esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, $varlist_sort)
            end

            Douglass.@with $t begin
                keepme = BitArray{1}(trues(size($t,1)))
                # define _N 
                _N = size($t, 1)
                for _n in 1:size($t,1)
                    if (isnothing($filter) ? false : $filter)  # if condition is not satisfied, leave with missing
                        keepme[_n] = 0
                    end
                end
                filter!(r -> keepme[DataFrames.row(r)] , $t)
            end
            
        end
    )
end