
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

# # the goal of this is just to return a string with the interpolated string
# macro m_str(str)
#     #esc(Meta.parse("\"$(escape_string(str))\""))
#     esc(Expr(:macrocall, Symbol("@d_exp_str"), @__LINE__, string(Meta.parse("\"$(escape_string(str))\"")) ) )
# end

# # experimental interface
# macro d_exp_str(str)
#     # parse the command
#     println("d_exp_str: String = $str")
#     cmd = Douglass.parse(str)
#     # return the call to the appropriate macro
#     # return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__))
#     # return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__, Douglass.active_df, cmd.arguments))
#     return esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__, 
#         Douglass.active_df,
#         cmd.by,
#         cmd.sort,
#         cmd.arguments,
#         cmd.filter,
#         cmd.use,
#         cmd.options ))
# end