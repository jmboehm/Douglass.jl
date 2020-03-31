# this is the general form of the command
# let it fail with an error, because we don't allow all these blocks
macro drop(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Expr, Nothing}, 
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
macro drop(t::Symbol, by::Nothing, sort::Nothing, arguments::Expr, filter::Nothing, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@drop_var!($t, $arguments)
        end
    )
end

# this is `drop if <condition>`
macro drop(t::Symbol, by::Nothing, sort::Nothing, arguments::Nothing, filter::Expr, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@drop_if!($t, $filter)
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