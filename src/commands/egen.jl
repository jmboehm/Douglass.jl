"""
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

As in Stata, `if` conditions restrict the set of rows that are being used for the RHS *and* the set of observations
that are being assigned to. 

Stata's `egen` is inconsistent on how missing values are handled. Some `egen` commands (like `mean()`) ignore all rows 
that have missing values for one of the variables used on the right-hand side. Other commands (like `rowtotal()`) 
by default use all rows. 
The default behavior of Douglass's `egen` is to ignore all rows that have `missing` entries for 
one or more variables in the right-hand side expression. That does _not_ include columns used in the `if` statement.

Differences to Stata:
  - Type declarations are done via `d"egen :x::Float64 = :y .+ :z"`. Types are from Julia, of course (which means we can finally use 64-bit Integers!)
  - Note that any function used in the expression on the RHS needs to be defined. For example, `total` is not a base Julia function, and will not 'work' out of the box.
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

# Stata's behavior:
#
#   - `if` restricts both the input and output rows to the ones that satisfy this condition
#   - `egen` does not by default restrict the input rows to those that are nonmissing for all RHS variables, but for some operations it does. 
#       It never restricts the set of output rows to the nonmissing ones
#
# We follow Stata's behavor on [if], and, by default, restrict the input set to those that are nonmissing for all variables

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
        error("Expected a Symbol on the left-hand side of `egen` assignment operation, found Expr.")
        # ( arguments.args[1].head == Symbol("::") ) || error("Expected data type in assignment operation, e.g. `:x::Float64 = ...`")
        # (size(arguments.args[1].args,1) == 2 ) || error("Expected data type in assignment operation, e.g. `:x::Float64 = ...`")
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
        transformation = Expr(:call, identity, arguments.args[2])
    else
        transformation = Expr(:call, identity, arguments.args[2])
    end

    # println("transformation is a $(typeof(transformation)) with value $(transformation).")
    # println("assigned_var_qn is a $(typeof(assigned_var_qn)) with value $(assigned_var_qn).")

    return esc(
        quote 
            # check variable is not present
            ($(assigned_var_qn) ∉ propertynames($t)) || error("Variable $($(assigned_var_qn)) already present in DataFrame.")
            # do the assignment
            Douglass.@transform_byvec_allobs!($t, $varlist_by, $varlist_sort, $assigned_var_qn, $transformation, $filter)
        end
    )
end

# vector-wise transformation with `if` condition (`by` and `if`)
# reference implementation
macro transform_byvec_allobs!(t::Symbol, 
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
    # add an index subscript to all arg's: arg[#] -> arg[#][index]
    # so that we can condition on a filter
    push_index!(transformation_converted, :indices, :args)

    # a vector of the Symbol's for each QuoteNode
    symbol_vec = [qn_vec[i].value for i=1:length(qn_vec)]

    # DEEBUGGING OUTPUT:
    # println("transformation_converted is a $(typeof(transformation_converted)) with value $(transformation_converted).")
    # println("filter_converted is a $(typeof(filter_converted)) with value $(filter_converted).")
    # println("qn_vec is a $(typeof(qn_vec)) with value $(qn_vec).")
    # println("first element is a $(typeof(qn_vec[1])) with value $(qn_vec[1]).")
    # @show qn_vec[1]
    # dump(transformation_converted)

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
                # the following is a wrapper for a[indices] = $transformation_converted
                # but if $transformation_converted expands into a scalar, it's broadcast
                return Douglass.assign_helper_gen(indices,$transformation_converted)
            end
            transform!(groupby($t, $varlist_by, sort=false, skipmissing = true ), $(symbol_vec) => my_f => $(assigned_var_qn))        
        end

    )
end

# `by` but no `if`
macro transform_byvec_allobs!(t::Symbol, 
    varlist_by::Vector{Symbol}, 
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
macro transform_byvec_allobs!(t::Symbol, 
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
    # add an index subscript to all arg's: arg[#] -> arg[#][index]
    # so that we can condition on a filter
    push_index!(transformation_converted, :indices, :args)

    # a vector of the Symbol's for each QuoteNode
    symbol_vec = [qn_vec[i].value for i=1:length(qn_vec)]

    # println("transformation_converted is a $(typeof(transformation_converted)) with value $(transformation_converted).")
    # println("filter_converted is a $(typeof(filter_converted)) with value $(filter_converted).")
    # println("qn_vec is a $(typeof(qn_vec)) with value $(qn_vec).")
    # println("first element is a $(typeof(qn_vec[1])) with value $(qn_vec[1]).")
    # @show qn_vec[1]
    # dump(transformation_converted)

    return esc(
        quote
            # define a barrier function, which will be compiled and type stable
            # see Ch. 11 of Bogumil Kaminski's DataFrames tutorial
            local function my_f(args...)
                # indices are the indices of the input columns to be used.
                indices = BitArray($filter_converted)
                # the following is a wrapper for a[indices] = $transformation_converted
                # but if $transformation_converted expands into a scalar, it's broadcast
                return Douglass.assign_helper_gen(indices,$transformation_converted)
            end
            transform!($t, $(symbol_vec) => my_f => $(assigned_var_qn))        
        end
    )
end
# version without `by` and `if`
macro transform_byvec_allobs!(t::Symbol, 
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