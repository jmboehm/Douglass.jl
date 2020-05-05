

"""
`duplicates_drop`

Syntax:
    `duplicates_drop <varlist>`

Drops all but the first occurrence of each tupe of unique values denoted by <varlist>
Examples:
```julia
d"duplicates_drop :Species"
```

Differences to Stata:

"""
macro duplicates_drop(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            duplicates_drop <varlist>
    """)
end

macro duplicates_drop(t::Symbol, 
    by::Nothing, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@duplicates_drop!($t, $by, $sort, $arguments, $filter, $use, $options)
        end
    )
end


macro duplicates_drop!(t::Symbol, 
    by::Nothing, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::Nothing, 
    options::Union{Dict{String,Any}, Nothing})
    esc(
        quote
            # sort, if we need to, (first by-variables, then sort-variables)
            if !isnothing($(sort)) && !isempty($(sort))
                sort!($t, $sort)
            end
            # assert that variables are present
            Douglass.@assert_vars_present($t, $arguments)
            # make unique
            unique!($t, $arguments)
        end
    )
end
