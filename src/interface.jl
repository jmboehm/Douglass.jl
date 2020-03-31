
# we need some packages outside
using DataFramesMeta

macro d_str(str)
    # parse the command
    cmd = Douglass.parse(str)
    # return the call to the appropriate macro
    # return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__))
    # return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__, Douglass.active_df, cmd.arguments))
    return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__, 
        Douglass.active_df,
        cmd.by,
        cmd.sort,
        cmd.arguments,
        cmd.filter,
        cmd.use,
        cmd.options ))
end