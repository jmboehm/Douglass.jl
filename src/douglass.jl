# douglass.jl

module Douglass

    using Tables, DataFrames, DataFramesMeta

    # rename the column `var` to `to`
    # uses DataFrames
    function rename(t, var::Symbol, to::Symbol)

        !Tables.istable(t) && error("Object t is not of a type that extends the Tables.jl interface.")

        # uses DataFrames
        rename!(t, var => to)

    end

    function gen(t, varname::Symbol, vec::Vector{T}) where {T}
        if varname ∈ names(t)
            error("Table already has a column with this name.")
        end
        if length(vec) != size(t,1)
            error("Vector is not of the same length as the table.")
        end
        t[!,varname] = deepcopy(vec)  # note that this makes a copy
    end

    # generate a variable named `varname` that contains vec
    # function gen(t, varname::Symbol, s::String)
    #     if varname ∈ names(t)
    #         error("Table already has a column with this name.")
    #     end
    #     x = @with(t, s)
    #     @show x
    #     t[!,varname] = x
    # end

    macro generate!(t,varname,ex)
        esc(
            quote
                if $varname ∈ names($t)
                    error("Table already has a column with this name.")
                end
                local x = @with($t, $ex)
                # if we have a scalar, broadcast
                if size(x,1) == 1
                    $t[!,$varname] .= x
                else 
                    $t[!,$varname] = x
                end
            end
        )
    end

    macro replace!(t,varname,ex)
        esc(
            quote
                if $varname ∉ names($t)
                    error("Variable $(varname) does not exist.")
                end
                local x = @with($t, $ex)
                # if we have a scalar, broadcast
                if size(x,1) == 1
                    $t[!,$varname] .= x
                else 
                    $t[!,$varname] = x
                end
            end
        )
    end

    # # Stata prefix syntax
    # struct Prefix
    #     prefix::Symbol
    #     varlist::Vector{Symbol}

    # end

    # # Stata command format:
    # #  [prefix :] command [varlist] [=exp] [if] [in] [weight] [using filename] [, options]
    # # to this we add [frame] at the start, so that it becomes
    # # [frame] [prefix :] command [varlist] [=exp] [if] [in] [weight] [using filename] [, options]
    # struct Command
    #     frame::DataFrame
    #     prefix::Prefix
    #     command::Function
    #     varlist::Vector{Symbol}

    #     end
    # end

    # macro douglass(ex::Expr...)
    #     for i = 1:length(ex)
    #         @show ex[i]
    #     end
    # end


    # function egen(df::DataFrame,        # DF on which we operate
    #     byVarlist::Vector{Symbol},      # by variables
    #     sortVarlist::Vector{Symbol},    # sort variables
    #     newVarname::Symbol,             # newly generated symbol
    #     fct::Function,                  # function to use
    #     args::Vector{Symbol})           # argument list to the function

    # end

end

#@douglass bysort(var1,var2) frame(df) command(egen) args(arg1,arg2) if(condition) in(range) using(strfile) 

