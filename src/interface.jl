

macro d_str(str)
    # parse the command
    cmd = Douglass.parse(str)
    # return the call to the appropriate macro
    return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__))
end
