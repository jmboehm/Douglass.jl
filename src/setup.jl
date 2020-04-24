function __init__()
    # set up REPL mode 
    isdefined(Base, :active_repl) &&
        isinteractive() && typeof(Base.active_repl) != REPL.BasicREPL &&
            !DouglassPrompt.repl_inited(Base.active_repl) && DouglassPrompt.repl_init(Base.active_repl)
end