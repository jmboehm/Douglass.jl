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
    options::Union{Dict{String,Any}, Nothing})
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
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            @replace(t, by, sort, arguments, filter, use, options)
        end
    )
end

# version with by
macro replace(t::Symbol, 
    by::Vector{Symbol}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@replace_byrow!($t, $by, $sort, $arguments, $filter, $options )
        end
    )
end

# version without by
macro replace(t::Symbol, 
    by::Nothing, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing}, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@replace_byrow!($t, $sort, $arguments, $filter )
        end
    )
end

# version with `by`
macro replace_byrow!(t::Symbol, varlist_by::Vector{Symbol}, varlist_sort::Union{Vector{Symbol}, Nothing}, arguments::Expr, filter::Union{Expr, Nothing}, options::Union{Dict{String,Any}, Nothing})
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
    transformation = arguments.args[2]
    # return `nothing`s in case the index is < 1
    isexpr(transformation) && replace_invalid_indices!(transformation)

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
                # define _N 
                _N = size(_df, 1)
                # fill the new variable, row by row
                for _n in 1:size(_df,1)
                    if (isnothing($filter) ? true : $filter)  # if condition is not satisfied, leave with missing
                        $(assigned_var_qn)[_n] = $(transformation)
                    end
                end
                _df
            end
            # execute, and copy it to another dataframe, 
            # otherwise we get copies of the group variables in there as well
            t2 = by($t, $varlist_by, my_f )
            @with $t begin
                for _n = 1:size($t,1)
                    if (isnothing($filter) ? true : $filter)
                        $(assigned_var_qn)[_n] = t2[_n,^($(assigned_var_qn))]
                    end 
                end
            end
            $t
        end
    )
end


# version without `by`
macro replace_byrow!(t::Symbol, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Expr, 
    filter::Union{Expr, Nothing})

    # assert that `arguments` is an assignment
    (arguments.head == :(=)) || error("`replace` expects an assignment operation, e.g. :x = :y + :z")
    # replace :varname by :varname[i] if not referenced
    Douglass.ref_quotenodes!(arguments)
    !isnothing(filter) && Douglass.ref_quotenodes!(filter)
    # get the assigned var symbol and QuoteNode 
    @show arguments.args[1]
    if isa(arguments.args[1], Symbol)
        assigned_var_qn = QuoteNode(arguments.args[1])
    elseif isexpr(arguments.args[1]) && (arguments.args[1].head == :$)
        # interpolate
        # Now this becomes a Symbol
        assigned_var_qn = arguments.args[1].args[1] # ")  #QuoteNode(arguments.args[1].args[1]) #
    elseif isa(arguments.args[1].args[1], QuoteNode)
        # and the QuoteNode
        assigned_var_qn = arguments.args[1].args[1]
    else
        error("Assigned variable must be referenced using the colon syntax, e.g. :x.")
    end
    @show assigned_var_qn

    # if the RHS of the assignment expression is currently a symbol, make it an Expr
    #transformation = (typeof(arguments.args[2]) == Symbol) ? Expr(arguments.args[2]) : arguments.args[2]
    transformation = arguments.args[2]
    # return `nothing`s in case the index is < 1

    isexpr(transformation) && replace_invalid_indices!(transformation)

    return esc(
        quote
            # check variable is present
            ($(assigned_var_qn) ∉ names($t)) && error("Variable $($(assigned_var_qn)) not present in DataFrame.")
            
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, $varlist_sort)
            end

            @with $t begin
                # define _N 
                _N = size($t, 1)
                # fill the new variable, row by row
                for _n in 1:size($t,1)
                    if (isnothing($filter) ? true : $filter)  # if condition is not satisfied, leave with missing
                        $(assigned_var_qn)[_n] = $(transformation)
                        # This is what needs to be used if the assigned_var_qn is a Symbol
                        #$t[_n, $(assigned_var_qn)] = $(transformation)
                    end
                end
                $t
            end
            $t
        end
    )
end