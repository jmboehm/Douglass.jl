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
# ex = :( x[i] = y[i-1] )
# ex = :((:x)[i - 1])
# dump(ex)
# replace_invalid_indices!(ex)