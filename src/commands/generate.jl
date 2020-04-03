#
# `generate`
# 
# Differences to Stata:
#   - The current observation is denoted by `i` instead of `_n`, e.g. `:varname[i]` instead of `:varname[_n]`
#
# Like in Stata, refering to a variable by `:varname` implicitly means the current row: `:varname[i]`
#
# this is the general form of the command
macro generate(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,String}, Nothing})
    error("""\n
        The syntax is:
            generate <expression> [if] <expression>
        or 
            bysort <varlist> (<varlist>): generate <expression> [if] <expression>
    """)
end

# short form. This is a copy of the above for `gen`.
macro gen(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,String}, Nothing})
    return esc(
        quote
            @generate(t, by, sort, arguments, filter, use, options)
        end
    )
end

macro generate(t::Symbol, 
    by::Vector{Symbol}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,String}, Nothing})
    return esc(
        quote
            Douglass.@generate_byrow!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end

macro generate_byrow!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Union{Expr, Nothing}, options::Union{Dict{String,String}, Nothing})
    # assert that `arguments` is an assignment
    (arguments.head == :(=)) || error("`generate` expects an assignment operation, e.g. :x = :y + :z")
    # replace :varname by :varname[i] if not referenced
    Douglass.ref_quotenodes!(arguments)
    !isnothing(filter) && Douglass.ref_quotenodes!(filter)
    # get the assigned var symbol (note that it's in a QuoteNode)
    assigned_var = arguments.args[1].args[1].value
    # and the QuoteNode
    assigned_var_qn = arguments.args[1].args[1]
    
    # if the RHS of the assignment expression is not an expression, make it one
    transformation = isexpr(arguments.args[2]) ? arguments.args[2] : Expr(arguments.args[2])
    return esc(
        quote
            # check variable is not present
            ($(assigned_var) ∉ names($t)) || error("Variable $($(assigned_var)) already present in DataFrame.")
            
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end
            #determine type of resulting column from the type of the first element
            assigned_var_type = eltype([@with($t,$(transformation)) for i=1])
            $t[!,$(assigned_var)] = missings(assigned_var_type,size($t,1))

            # this is the function that maps every sub-df into its transformed df
            my_f = _df -> @with _df begin
                # fill the new variable, row by row
                for i in 1:size(_df,1)
                    if (isnothing($filter) ? true : $filter)  # if condition is not satisfied, leave with missing
                        $(assigned_var_qn)[i] = $(transformation)
                    end
                end
                _df
            end
            # execute, and copy it to another dataframe, 
            # otherwise we get copies of the group variables in there as well
            t2 = by($t, $varlist_by, my_f )
            $t[!,$(assigned_var)] = missings(eltype(t2[!,$(assigned_var)]),size($t,1))
            $t[!,$(assigned_var)] = t2[!,$(assigned_var)]
            $t
        end
    )
end

# # main version, doing stuff by row using @with (which has the advantage that we can use "[i]" syntax)
# # todo: 
# #   allow _n 
# #   assume that user means [i] if no index is shown (in transformation and filter)
# macro generate_byrow!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, assigned_var_type, transformation::Expr, filter)
#     # @show assigned_var
#     # @show typeof(assigned_var)
#     # @show transformation
#     esc(
#         quote
#             # check that assigned_var_type is a valid type
#             isa($(assigned_var_type),DataType) || error("assigned_var_type must be a DataType")

#             # check variable is not present
#             ($(assigned_var) ∉ names($t)) || error("Variable $(assigned_var) already present in DataFrame.")
#             $t[!,$(assigned_var)] = missings($assigned_var_type,size($t,1))

#             # sort, if we need to, (first by-variables, then sort-variables)
#             if !isempty($(varlist_sort))
#                 sort!($t, vcat($varlist_by, $varlist_sort))
#             end
            
#             # this is the function that maps every sub-df into its transformed df
#             my_f = _df -> @with _df begin
#                 # fill the new variable, row by row
#                 for i in 1:size(_df,1)
#                     if ($filter)  # if condition is not satisfied, leave with missing
#                         $(assigned_var)[i] = $(transformation)
#                     end
#                 end
#                 _df
#             end
#             # execute, and copy it to another dataframe, 
#             # otherwise we get copies of the group variables in there as well
#             t2 = by($t, $varlist_by, my_f )
#             $t[!,$(assigned_var)] = t2[!,$(assigned_var)]
#             $t
#         end
#     )
# end

# macro generate!(t,varname,ex,filter)
#     esc(
#         quote
#             if $varname ∈ names($t)
#                 error("Table already has a column with this name.")
#             end
#             local x = @with($t, ifelse.($filter, $ex , missing))
#             # if we have a scalar, broadcast
#             if size(x,1) == 1
#                 $t[!,$varname] .= x
#             else 
#                 $t[!,$varname] = x
#             end
#         end
#     )
# end

# @generate! without if-filter
macro generate!(t,varname,ex)
    return esc( :( Douglass.@generate!($t,$varname,$ex,true) )  )
end


# # this is an alternative version that uses @byrow! Has the advantage that we don't need to use vectorized syntax, but not much else
# macro generate_byrow2!(t::Symbol, varlist_by::Expr, varlist_sort::Expr, assigned_var, assigned_var_type::Expr, transformation::Expr, filter::Expr, arguments::Expr)
#     esc(
#         quote
#             # create arguments in a local scope
#             args = $arguments

#             # check variable is not present
#             ($(assigned_var) ∉ names($t)) || error("Variable $(assigned_var) already present in DataFrame.")

#             # this is the function that maps every sub-df into its transformed df
#             my_f = _df -> @byrow! _df begin
#                 @newcol $assigned_var::Array{Union{$assigned_var_type, Missing},1}
#                 $(assigned_var) = $(transformation)
#             end
#             $t = by($t, $varlist_by, my_f )
#             $t
#         end
#     )
# end

