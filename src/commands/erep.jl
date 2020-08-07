
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
    
    # make sure transformation is an Expr
    if isexpr(arguments.args[2])
        transformation = arguments.args[2]
    elseif isa(arguments.args[2], QuoteNode)
        transformation = Expr(:call, identity, arguments.args[2])
    else 
        transformation = Expr(:call, identity, arguments.args[2])
    end

    return esc(
        quote
            # check variable is present
            ($(assigned_var_qn) ∈ propertynames($t)) || error("Variable $($(assigned_var_qn)) not present in DataFrame.")
            # do the assignment
            Douglass.@replace_byvec_allobs!($t, $varlist_by, $varlist_sort, $assigned_var_qn, $transformation, $filter)
        end
    )
end

macro replace_byvec_allobs!(t::Symbol, 
    varlist_by::Vector{Symbol}, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Expr)
    
    # go through the expression tree and pick up QuoteNodes.
    qn_vec = Vector{QuoteNode}()
    transformation_converted = deepcopy(transformation)
    filter_converted = deepcopy(filter)
    
    # replace all QuoteNode's by args[x]
    replace_QuoteNodes!(transformation_converted, :args, qn_vec)
    # and the same for the filter condition
    replace_QuoteNodes!(filter_converted, :args, qn_vec)
    # add $assigned_var_qn if not already present
    idx_assigned_var_qn = 0
    idx = findfirst(isequal(assigned_var_qn), qn_vec)
    if !isnothing(idx)
        # already exists in qn_vec
        idx_assigned_var_qn = idx
    else
        push!(qn_vec, assigned_var_qn)
        idx_assigned_var_qn = length(qn_vec)
    end
    # add an index subscript to all arg's: arg[#] -> arg[#][index]
    # so that we can condition on a filter
    push_index!(transformation_converted, :indices, :args)

    # a vector of the Symbol's for each QuoteNode
    symbol_vec = [qn_vec[i].value for i=1:length(qn_vec)]

    return esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end

            # define a barrier function, which will be compiled and type stable
            # see Ch. 11 of Bogumil Kaminski's DataFrames tutorial
            local function my_f(args...)
                # indices are the indices of the input columns to be used.
                indices = BitArray($filter_converted)
                # the following is a wrapper for args[idx_assigned_var_qn][indices] = $transformation_converted
                # but if $transformation_converted expands into a scalar, it's broadcast
                return Douglass.assign_helper_rep!(args[$idx_assigned_var_qn],indices,$transformation_converted)
            end
            transform!(groupby($t, $varlist_by, sort=false, skipmissing = true ), $(symbol_vec) => my_f => $(assigned_var_qn))        
        end

    )
end
# `by` but no `if`
macro replace_byvec_allobs!(t::Symbol, 
    varlist_by::Vector{Symbol}, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Nothing)
    
    # go through the expression tree and pick up QuoteNodes.
    qn_vec = Vector{QuoteNode}()
    transformation_converted = deepcopy(transformation)
    filter_converted = deepcopy(filter)
    
    # replace all QuoteNode's by args[x]
    replace_QuoteNodes!(transformation_converted, :args, qn_vec)

    # a vector of the Symbol's for each QuoteNode
    symbol_vec = [qn_vec[i].value for i=1:length(qn_vec)]

    return esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(varlist_sort)) && !isempty($(varlist_sort))
                sort!($t, vcat($varlist_by, $varlist_sort))
            end

            # define a barrier function, which will be compiled and type stable
            # see Ch. 11 of Bogumil Kaminski's DataFrames tutorial
            local function my_f(args...)
                return $transformation_converted
            end
            transform!(groupby($t, $varlist_by, sort=false, skipmissing = true ), $(symbol_vec) => my_f => $(assigned_var_qn))        
        end

    )
end

# version without groups but with if
macro replace_byvec_allobs!(t::Symbol, 
    varlist_by::Nothing, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Expr)
    
    # go through the expression tree and pick up QuoteNodes.
    qn_vec = Vector{QuoteNode}()
    transformation_converted = deepcopy(transformation)
    filter_converted = deepcopy(filter)
    
    # replace all QuoteNode's by args[x]
    replace_QuoteNodes!(transformation_converted, :args, qn_vec)
    # and the same for the filter condition
    replace_QuoteNodes!(filter_converted, :args, qn_vec)
    # add $assigned_var_qn if not already present
    idx_assigned_var_qn = 0
    idx = findfirst(isequal(assigned_var_qn), qn_vec)
    if !isnothing(idx)
        # already exists in qn_vec
        idx_assigned_var_qn = idx
    else
        push!(qn_vec, assigned_var_qn)
        idx_assigned_var_qn = length(qn_vec)
    end
    # add an index subscript to all arg's: arg[#] -> arg[#][index]
    # so that we can condition on a filter
    push_index!(transformation_converted, :indices, :args)

    # a vector of the Symbol's for each QuoteNode
    symbol_vec = [qn_vec[i].value for i=1:length(qn_vec)]

    return esc(
        quote
            # define a barrier function, which will be compiled and type stable
            # see Ch. 11 of Bogumil Kaminski's DataFrames tutorial
            local function my_f(args...)
                # indices are the indices of the input columns to be used.
                indices = BitArray($filter_converted)
                # the following is a wrapper for a[indices] = $transformation_converted
                # but if $transformation_converted expands into a scalar, it's broadcast
                return Douglass.assign_helper_rep!(args[$idx_assigned_var_qn],indices,$transformation_converted)
            end
            transform!($t, $(symbol_vec) => my_f => $(assigned_var_qn))        
        end
    )
end
# version without `by` and `if`
macro replace_byvec_allobs!(t::Symbol, 
    varlist_by::Nothing, 
    varlist_sort::Union{Vector{Symbol}, Nothing}, 
    assigned_var_qn::QuoteNode, 
    transformation, 
    filter::Nothing)

    # go through the expression tree and pick up QuoteNodes.
    qn_vec = Vector{QuoteNode}()
    transformation_converted = deepcopy(transformation)
    
    # replace all QuoteNode's by args[x]
    replace_QuoteNodes!(transformation_converted, :args, qn_vec)

    # a vector of the Symbol's for each QuoteNode
    symbol_vec = [qn_vec[i].value for i=1:length(qn_vec)]

    return esc(
        quote
            # define a barrier function, which will be compiled and type stable
            # see Ch. 11 of Bogumil Kaminski's DataFrames tutorial
            local function my_f(args...)
                return $transformation_converted
            end
            transform!($t, $(symbol_vec) => my_f => $(assigned_var_qn)) 
        end
    )
end