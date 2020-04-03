# this is the interface
macro sort(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Expr, Nothing})
    error("""\n
        The syntax is:
            sort <varlist>
    """)
end

# this is `sort <varlist>`
macro sort(t::Symbol, by::Nothing, sort::Nothing, arguments::Vector{Symbol}, filter::Nothing, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@sort!($t, $arguments)
        end
    )
end

macro sort!(t::Symbol, varlist::Vector{Symbol})
    esc(
        quote
            # check that all variables are present
            Douglass.@assert_vars_present($t, $varlist)
            sort!($t, $varlist)
        end
    )
end