
"""
`merge`

Syntax:
    `merge_11 <varlist> using <DataFrame> , [options]`
    `merge_m1 <varlist> using <DataFrame> , [options]`
    `merge_1m <varlist> using <DataFrame> , [options]`

Description

Performs 1:1, 1:m, and m:1 merges.

Examples:
```julia
people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
jobs = DataFrame(ID = [20, 20, 60], Job = ["Lawyer", "Economist", "Astronaut"])
Douglass.set_active_df(:people)
d"merge_1m :ID using jobs"
```

Notable differences to Stata:
  - Note that the commands are e.g. `merge_m1` not `merge m:1`. There is an underscore and the colon is missing.
  - The commands currently do not produce any variable `_merge` and no summary statistics.
  - m:m merges are currently not allowed.

Notes:
    - Julia's DataFrames.jl has SQL-type joins, of which the merges here are but a small subset-- so much more 
      powerful than this here.

"""
macro merge_11(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            merge_11 <varlist> using <DataFrame> , [options]
    """)
end


macro merge_11(t::Symbol, 
    by::Nothing, 
    sort::Nothing, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::String, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@merge!($t, :one_to_one, $arguments, $use, $options )
        end
    )
end

macro merge_m1(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            merge_m1 <varlist> using <DataFrame> , [options]
    """)
end
macro merge_m1(t::Symbol, 
    by::Nothing, 
    sort::Nothing, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::String, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@merge!($t, :m_to_one, $arguments, $use, $options )
        end
    )
end

macro merge_1m(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            merge_1m <varlist> using <DataFrame> , [options]
    """)
end
macro merge_1m(t::Symbol, 
    by::Nothing, 
    sort::Nothing, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::String, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@merge!($t, :one_to_m, $arguments, $use, $options )
        end
    )
end

macro merge_mm(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            merge_mm <varlist> using <DataFrame> , [options]
    """)
end
macro merge_mm(t::Symbol, 
    by::Nothing, 
    sort::Nothing, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::String, 
    options::Union{Dict{String,Any}, Nothing})
    return esc(
        quote
            Douglass.@merge!($t, :m_to_m, $arguments, $use, $options )
        end
    )
end


# merge <type> <keys> using <rhs> , [options]
# Note: this could also be a function, really
macro merge!(t::Symbol, type::QuoteNode, keys::Vector{Symbol}, rhs::String, options::Union{Dict{String,Any}, Nothing})
    
    # parse rhs
    ex_rhs = Meta.parse(rhs)
    #println("ex_rhs is a $(typeof(ex_rhs)) with value $(ex_rhs).")
    dump(ex_rhs)

    isa(ex_rhs, Symbol) || error("Merge operations expect a non-quoted symbol after `using`.")

    return esc(
        quote
            # make sure keys are present in both master and using
            # assert_vars_present($t, $keys)
            # assert_vars_present($rhs, $keys)
            for k in $keys
                (k ∈ names($t)) || error("Variable $(k) not present in active DataFrame.")
            end
            for k in $keys
                (k ∈ names($ex_rhs)) || error("Variable $(k) not present in RHS DataFrame.")
            end    

            # outer = 1:1 or m:1 
            # outer with lhs and rhs switched: 1:m

            # whenever the merge has a '1' in Stata, the keys must be uniquely identifying observations
            # this needs to be checked
            if ($type == :one_to_one) || ($type == :m_to_one)
                # check that we are restraining things correctly
                ($type == :one_to_one) && (Douglass.unique_obs($t, $keys) || error("Keys are not uniquely identifying observations in master DataFrame."))
                Douglass.unique_obs($ex_rhs, $keys) || error("Keys are not uniquely identifying observations in using DataFrame.")
                # do the merge
                $t = join($t, $ex_rhs, on = $keys, kind = :outer)
            elseif ($type == :one_to_m)
                Douglass.unique_obs($t, $keys) || error("Keys are not uniquely identifying observations in master DataFrame.")
                # do the merge
                $t = join($ex_rhs, $t, on = $keys, kind = :outer)
            elseif ($type == :m_to_m)
                error("m:m mergers are not allowed.")
            else
                error("Invalid merge type.")
            end
            $t
        end
    )
end

# This is just a helper to get the syntax right.
"""
`merge`

Syntax:
    `merge_11 <varlist> using <DataFrame> , [options]`
    `merge_m1 <varlist> using <DataFrame> , [options]`
    `merge_1m <varlist> using <DataFrame> , [options]`

"""
macro merge(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        `merge` does not exist. 
        For merges, the syntax is:
            `merge_11 <varlist> using <DataFrame> , [options]`
            `merge_m1 <varlist> using <DataFrame> , [options]`
            `merge_1m <varlist> using <DataFrame> , [options]`
    """)
end