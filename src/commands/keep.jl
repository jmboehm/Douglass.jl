# this is the interface
macro keep(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,String}, Nothing})
    error("""\n
        The syntax is:
            keep <varlist>
        or
            keep if <condition>
    """)
end

# this is `keep <varlist>`
macro keep(t::Symbol, by::Nothing, sort::Nothing, arguments::Vector{Symbol}, filter::Nothing, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@keep_var!($t, $arguments)
        end
    )
end

# this is `keep if <condition>`
macro keep(t::Symbol, by::Nothing, sort::Nothing, arguments::Nothing, filter::Expr, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@keep_if!($t, $filter)
        end
    )
end

# TODO add a version that allows for Vector{Symbol} arguments

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