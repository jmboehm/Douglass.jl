# this is the interface
macro rename(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            rename <var_from> <var_to>
    """)
end

# this is `keep <varlist>`
macro rename(t::Symbol, by::Nothing, sort::Nothing, arguments::Vector{Symbol}, filter::Nothing, use::Nothing, options::Nothing)
    return esc(
        quote 
            Douglass.@rename!($t, $arguments)
        end
    )
end


macro rename!(t::Symbol, arguments::Vector{Symbol})
    (size(arguments,1) == 2) || error("`rename` expects exactly two variable symbols.")
    # construct QuoteNode's
    from_qn = QuoteNode(arguments[1])
    to_qn = QuoteNode(arguments[2])
    return esc(
        quote
            ($(from_qn) ∈ names($t)) || error("Variable $($(from_qn)) not present in active DataFrame.")

            # uses DataFrames
            rename!($t, $(from_qn) => $(to_qn))
        end
    )
end