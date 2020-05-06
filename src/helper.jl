# goes through an expression and replace all QuoteNode's that are not in an expression with
# head = ref by an expression that ref's the i'th element
function ref_quotenodes!(e::Expr, headtype::Symbol = :top)
    if (e.head != :ref)
        for aind = 1:length(e.args)
            a = e.args[aind]
            if MacroTools.isexpr(a)
                ref_quotenodes!(a, e.head)
            elseif (typeof(a) == QuoteNode) && (headtype != :ref)
                # replace this
                e.args[aind] = Expr(:ref, a, :_n)
            end
        end
    end
    e
end

# removes the colon at the start of a string, if present
function stripcolon(s::AbstractString)
    return (length(s)>1 && s[1] == ':') ? s[2:end] : s
end

# replace all Expr that take the following form by an expression that evaluates to `missing` if the index is negative
# head: Symbol ref
# args: args: Array{Any}((2,))
#   1: Symbol y
#   2: Expr
function replace_invalid_indices!(ex::Expr)
    if (ex.head == :ref) && isa(ex.args[1], QuoteNode) && MacroTools.isexpr(ex.args[2])
        r = deepcopy(ex)
        myex = :( ($(ex.args[2]) < 1) ? missing : $(r) )
        ex.head = deepcopy(myex.head)
        ex.args = deepcopy(myex.args)
    else
        # keep going through the tree
        for a in ex.args
            MacroTools.isexpr(a) && replace_invalid_indices!(a)
        end
    end
    return ex
end

# returns `true` if `keys` uniquely identify rows in `df`, otherwise `false`
function unique_obs(df::DataFrame, keys::Vector{Symbol})
    return allunique(Tables.namedtupleiterator(df[!,keys]))
end

# expand the argument x to the length of the df if it's not already a vector
# first generic version that supports size(_,1)
function helper_expand(df, x)
    (ismissing(x) || size(x,1) == 1) ? repeat([x],size(df,1)) : x
end
# ... or to a length of l::Int64
function helper_expand(l::Int64, x)
    (ismissing(x) || size(x,1) == 1) ? repeat([x],l) : x
end


# Some helper macros

# helper macro to make sure filter is valid
macro assert_filter(t::Symbol, filter::Expr)
    esc(
        quote
            local x = @with($t, $filter)
            (typeof(x) <: BitArray{1}) || (typeof(x) <: Vector{Union{Missing,Bool}}) || error("filter is not a valid boolean vector.")
            true
        end
    )
end

# helper macro to make sure that expression evaluates to a Vector{Symbol}
macro assert_varlist(t::Symbol, varlist::Expr)
    esc(
        quote
            typeof($varlist) == Vector{Symbol} || error("Argument must be evaluating to a Vector{Symbol}. Type is $(typeof($varlist))")
            true
        end
    )
end
    
# asserts that varlist::Expr evaluates to a Vector{Symbol} and checks that all Symbols are column names in t.
macro assert_vars_present(t::Symbol, varlist::Expr)
    esc(
        quote
            # check that it's a varlist
            Douglass.@assert_varlist($t, $varlist)
            # check that they're present
            for v in $varlist
                (v ∈ names($t)) || error("$(v) not a column name in the active DataFrame")
            end
            true
        end
    )
end

# Checks that all Symbols are column names in t.
macro assert_vars_present(t::Symbol, varlist::Vector{Symbol})
    esc(
        quote
            # check that they're present
            ($varlist ⊆ names($t)) || error("$($varlist) is not a subset of the columns in the active DataFrame")
            true
        end
    )
end