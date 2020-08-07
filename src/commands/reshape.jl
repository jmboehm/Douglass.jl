"""
`reshape`

Syntax:
    `reshape_wide <varlist> , i(<varlist>) j(<varlist>)
    or 
    `reshape_long <varlist> , i(<varlist>) j(<varlist>)

Reshapes the active DataFrame between long and wide forms

Mnemonic: `i` are the **i**dentifying variables, i.e. the variables that should uniquely identify observations.

Examples:
```julia
include("src/Douglass.jl")
df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
df.id = collect(1:(size(df,1)))

d"reshape_long :Sepal :Petal, i(:id) j(:Var)"
d"reshape_wide :Sepal :Petal, i(:id) j(:Var)"
```

Notable differences to Stata:
  - Note that there is an underscore between `reshape` and `long`/`wide`, not a whitespace.
  - Unlike in Stata, `@` cannot be used as a whitecard.
  - In wide->long:
    * Unlike in Stata, the variable in j() is made to have type `Symbol` and is not automatically converted to `String` or numerical types.
    * Unlike in Stata, variables that are not listed in the arguments, `i`, or `j` are not part out the returned DataFrame. If you want to include them, list them as part of `i`.
"""
macro reshape(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        `reshape` does not exist.
        To do reshaping operations, use one of the following syntax:
            `reshape_wide <varlist> , i(<varlist>) j(<varlist>)
            `reshape_long <varlist> , i(<varlist>) j(<varlist>)
    """)
end

macro reshape_wide(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            `reshape_wide <varlist> , i(<varlist>) j(<varlist>)
    """)
end
macro reshape_wide(t::Symbol, 
    by::Nothing, 
    sort::Nothing, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::Nothing, 
    options::Dict{String,Any})
    return esc(
        quote
            Douglass.@reshape_wide!($t, $arguments, $options)
        end
    )
end


macro reshape_long(t::Symbol, 
    by::Union{Vector{Symbol}, Nothing}, 
    sort::Union{Vector{Symbol}, Nothing}, 
    arguments::Union{Vector{Symbol},Union{Expr, Nothing}}, 
    filter::Union{Expr, Nothing}, 
    use::Union{String, Nothing}, 
    options::Union{Dict{String,Any}, Nothing})
    error("""\n
        The syntax is:
            `reshape_long <varlist> , i(<varlist>) j(<varlist>)
    """)
end
macro reshape_long(t::Symbol, 
    by::Nothing, 
    sort::Nothing, 
    arguments::Vector{Symbol}, 
    filter::Nothing, 
    use::Nothing, 
    options::Dict{String,Any})
    return esc(
        quote
            Douglass.@reshape_long!($t, $arguments, $options)
        end
    )
end

# widedf = unstack(longdf, :id, :variable, :value);
# `variable` contains the stuff that will be appended to `stub1`, `stub2`, ...
# reshape wide stub1 stub2 , i(id) j(variable)

macro reshape_wide!(t::Symbol, 
    arguments::Vector{Symbol}, 
    options::Dict{String,Any})

    # check that options include i and j 
    haskey(options, "i") || error("`reshape_wide` operations must contain an option `i`.")
    haskey(options, "j") || error("`reshape_wide` operations must contain an option `j`.")

    # parse option varlists 
    #i_varlist = parse_varlist(options["i"])
    if isa(options["i"], QuoteNode)
        i_varlist = [options["i"].value]
    elseif isa(options["i"], Vector{QuoteNode})
        i_varlist = [options["i"][i].value for i=1:length(options["i"])]
    elseif isa(options["i"], Symbol)
        i_varlist = [options["i"]]
    elseif isa(options["i"], Vector{Symbol})
        i_varlist = options["i"]
    else
        println("i-options is a $(typeof(options["i"])) with value $(options["i"]).")
        error("Invalid option i()")
    end
    if isa(options["j"], QuoteNode)
        j_varlist_qn = [options["j"]]
    elseif isa(options["j"], Symbol)
        j_varlist_qn = [QuoteNode(options["j"])]
    elseif isa(options["j"], Vector{Symbol})
        j_varlist_qn = QuoteNode.(options["j"])
    else
        println("j-options is a $(typeof(options["j"])) with value $(options["j"]).")
        error("Invalid option j()")
    end
 #   j_varlist = parse_varlist(options["j"])

    # check that `j` only contains one variable
    length(i_varlist) > 0 || error("`reshape_wide` expects at least one variable as argument in the option `i()`.")
    length(j_varlist_qn) == 1 || error("`reshape_wide` expects one variable as argument in the option `j()`.")
    j_var_qn = j_varlist_qn[1]

    stubs = arguments
    stubs_qn = QuoteNode.(arguments)

    ij_varlist = cat(i_varlist, [j_varlist_qn[i].value for i=1:length(j_varlist_qn)], dims=1)
    # println("i_varlist_qn is a $(typeof(i_varlist)) with value $(i_varlist).")
    # println("j_var_qn is a $(typeof(j_var_qn)) with value $(j_var_qn).")
    # println("stubs_qn is a $(typeof(stubs_qn)) with value $(stubs_qn).")

    if length(stubs_qn) == 1
        s = stubs_qn[1]
        return esc(
            quote
                # check that i_varlist_qn and j_varlist_qn together uniquely identify observations
                #Douglass.@duplicates_assert($t, $ij_varlist)
                allunique(Tables.namedtupleiterator($t[!,$ij_varlist])) || 
                    error("i() and j() variables do not uniquely identify observations in DataFrame.")

                $t = unstack($t, $i_varlist, $j_var_qn, $s)
                # rename variables in the df
                for n in propertynames($t)
                    # ignore id
                    (n ∈ $i_varlist) && continue;
                    # rename the variables
                    new_col_name = Symbol("$($(s))" * String(n))
                    rename!($t, n => new_col_name)
                end
                $t
            end
        )
    else
        return esc(
            quote
                #check that i_varlist_qn and j_varlist_qn together uniquely identify observations
                # Douglass.@duplicates_assert($t, $ij_varlist)
                allunique(Tables.namedtupleiterator($t[!,$ij_varlist])) || 
                    error("i() and j() variables do not uniquely identify observations in DataFrame.")

                dfv = Vector{typeof($t)}(undef,length($stubs_qn))
                s = $(stubs)
                # unstack for each stub
                for i = 1:length($stubs_qn)
                    dfv[i] = unstack($t, $i_varlist, $j_var_qn, s[i])
                end
                # rename variables in the first df
                for n in propertynames(dfv[1])
                    # ignore id
                    (n ∈ $i_varlist) && continue;
                    # rename the variables
                    new_col_name = Symbol("$(s[1])" * String(n))
                    rename!(dfv[1], n => new_col_name)
                end
                # copy over the columns from the remaining df's
                for i = 2:length($stubs_qn)
                    for n in propertynames(dfv[i])
                        # ignore id
                        (n ∈ $i_varlist) && continue;
                        # otherwise copy over the new variables
                        new_col_name = Symbol("$(s[i])" * String(n))
                        dfv[1][!,new_col_name] = dfv[i][!,n]
                    end
                end
                $t = dfv[1]
            end
        )
    end
end

# if no i-variables are given, we default to all non-measure_vars.
macro reshape_long!(t::Symbol, 
    arguments::Vector{Symbol}, 
    options::Dict{String,Any})

    haskey(options, "i") || error("`reshape_wide` operations must contain an option `i`.")
    haskey(options, "j") || error("`reshape_wide` operations must contain an option `j`.")

    # parse option varlists 
    #i_varlist = parse_varlist(options["i"])
    if isa(options["i"], QuoteNode)
        i_varlist = [options["i"].value]
    elseif isa(options["i"], Vector{QuoteNode})
        i_varlist = [options["i"][i].value for i=1:length(options["i"])]
    elseif isa(options["i"], Symbol)
        i_varlist = [options["i"]]
    elseif isa(options["i"], Vector{Symbol})
        i_varlist = options["i"]
    else
        println("i-options is a $(typeof(options["i"])) with value $(options["i"]).")
        error("Invalid option i()")
    end
    if isa(options["j"], QuoteNode)
        j_varlist_qn = [options["j"]]
    elseif isa(options["j"], Symbol)
        j_varlist_qn = [QuoteNode(options["j"])]
    elseif isa(options["j"], Vector{Symbol})
        j_varlist_qn = QuoteNode.(options["j"])
    else
        println("j-options is a $(typeof(options["j"])) with value $(options["j"]).")
        error("Invalid option j()")
    end
    
    #length(i_varlist) > 0 || error("`reshape_wide` expects at least one variable as argument in the option `i()`.")
    # check that `j` only contains one variable
    length(j_varlist_qn) == 1 || error("`reshape_wide` expects one variable name as argument in the option `j()`.")
    j_var_qn = j_varlist_qn[1]
    j_var = j_var_qn.value

    stubs = arguments

    stubs_qn = QuoteNode.(arguments)
    # println("i_varlist_qn is a $(typeof(i_varlist)) with value $(i_varlist).")
    # println("j_var_qn is a $(typeof(j_var_qn)) with value $(j_var_qn).")
    # println("stubs_qn is a $(typeof(stubs_qn)) with value $(stubs_qn).")

    return esc(
        quote
            stubs = $stubs
            # get all variables in the dataframe that have the pattern stub*
            variables_by_stub = Vector{Vector{Symbol}}(undef, length(stubs))
            n = propertynames($t)
            n_str = String.(n)
            for s_ind = 1:length(stubs) 
                stub_str = String(stubs[s_ind])
                variables_by_stub[s_ind] = [n[i] for i=1:length(n) if n_str[i][1:min(length(stub_str),end)] == stub_str]
            end
            # make sure that the sets of variables are disjoint:
            let u = Symbol[]
                for vv in variables_by_stub
                    u = union(u,vv)
                end
                (sum(length.(variables_by_stub)) == length(u)) || error("Sets of variables referenced by arguments are not disjoint")
            end
            
            # do the reshape(s)
            dfv = Vector{typeof($t)}(undef,length($stubs))
            for s_ind = 1:length($stubs)
                # rename the columns to remove "Stub"
                variables_by_stub_renamed = Symbol[]
                stub_length = length(String(stubs[s_ind]))
                for v in variables_by_stub[s_ind]
                    rename_to_str = String(v)
                    rename_to = length(rename_to_str) > stub_length ?  rename_to_str[(stub_length+1):end] : " "
                    rename!($t, v => Symbol(rename_to))
                    push!(variables_by_stub_renamed, Symbol(rename_to))
                end
                dfv[s_ind] = stack($t, variables_by_stub_renamed, $i_varlist, variable_name=$j_var_qn, value_name=stubs[s_ind])
                # drop the columns that we have used
                select!($t, Not(variables_by_stub_renamed))
            end
            # merge in the columns from the remaining df's
            for i = 2:length($stubs)
                for n in propertynames(dfv[i])
                    # ignore id
                    ((n ∈ $i_varlist) || (n == $j_var_qn)) && continue;
                    # otherwise merge in the new variables
                    dfv[1] = outerjoin(dfv[1], dfv[i], on = union($i_varlist, [$j_var_qn]), makeunique = false, indicator=nothing, validate=(false,false))
                end
            end
            $t = dfv[1]
        end
    )
end