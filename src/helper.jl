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
                e.args[aind] = Expr(:ref, a, :i)
            end
        end
    end
    e
end

# removes the colon at the start of a string, if present
function stripcolon(s::AbstractString)
    return (length(s)>1 && s[1] == ':') ? s[2:end] : s
end