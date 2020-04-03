struct Prefix 
    by::Union{Nothing, Vector{Symbol}}
    sort::Union{Nothing, Vector{Symbol}}
end

struct Command
    by::Union{Vector{Symbol}, Nothing}
    sort::Union{Vector{Symbol}, Nothing}
    command::String
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}
    filter::Union{Expr, Nothing}
    use::Union{String,Nothing}
    options::Union{Dict{String,String}, Nothing}
end

