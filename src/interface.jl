
macro d_str(str)
    # split the command by linebreaks
    s = split(str, r"\n|\r\n", limit=0, keepempty=false)
    # for each line, parse the string and construct the expression
    exs = Vector{Expr}()
    for i = 1:length(s)
        cmd = Douglass.parse(s[i])
        push!(exs, esc(Expr(:macrocall, Expr(:., :Douglass, QuoteNode(Symbol("@$(cmd.command)"))), @__LINE__, 
            Douglass.active_df,
            cmd.by,
            cmd.sort,
            cmd.arguments,
            cmd.filter,
            cmd.use,
            cmd.options )) )
    end
    # For debugging:
    # @show exs
    # and return it to the REPL
    return Expr(:block, exs...)
    
end

macro use(t::Symbol)
    s = string(t)
    return esc(:( Douglass.set_active_df( Symbol($s) ) ))
end

function set_active_df(df::Symbol)
    global active_df
    active_df = df
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