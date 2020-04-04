#
# `replace`
# 
# Replace the values for a variable in the DataFrame if the `filter` condition is met.   
# Operates row-by-row, therefore operators on scalars are expected. `replace` does not change the 
# data type of the assigned variable.
#
# See also the notes for `generate`.
#
# this is the general form of the command
macro replace(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,String}, Nothing})
    error("""\n
        The syntax is:
            replace <expression> [if] <expression>
        or 
            bysort <varlist> (<varlist>): replace <expression> [if] <expression>
    """)
end

# short form. This is a copy of the above for `gen`.
macro rep(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,String}, Nothing})
    return esc(
        quote
            @replace(t, by, sort, arguments, filter, use, options)
        end
    )
end

macro replace(t::Symbol, 
    by::Vector{Symbol}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,String}, Nothing})
    return esc(
        quote
            Douglass.@replace_byrow!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end

macro replace_byrow!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Union{Expr, Nothing}, options::Union{Dict{String,String}, Nothing})
    # assert that `arguments` is an assignment
    (arguments.head == :(=)) || error("`generate` expects an assignment operation, e.g. :x = :y + :z")
    # replace :varname by :varname[i] if not referenced
    Douglass.ref_quotenodes!(arguments)
    !isnothing(filter) && Douglass.ref_quotenodes!(filter)
    # get the assigned var symbol (note that it's in a QuoteNode)
    assigned_var = arguments.args[1].args[1].value
    # and the QuoteNode
    assigned_var_qn = arguments.args[1].args[1]
    
    # if the RHS of the assignment expression is currently a symbol, make it an Expr
    transformation = (typeof(arguments.args[2]) == Symbol) ? Expr(arguments.args[2]) : arguments.args[2]
    return esc(
        quote
            # check variable is not present
            ($(assigned_var_qn) ∈ names($t)) || error("Variable $($(assigned_var_qn)) not present in DataFrame.")
            
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end
            #determine type of resulting column from the type of the first element
            #assigned_var_type = eltype($t[!,$assigned_var_qn])
            #$t[!,$(assigned_var)] = missings(assigned_var_type,size($t,1))

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
            @with $t begin
                for i = 1:size($t,1)
                    if (isnothing($filter) ? true : $filter)
                        $(assigned_var_qn)[i] = t2[i,^($(assigned_var_qn))]
                    end 
                end
            end
            $t
        end
    )
end