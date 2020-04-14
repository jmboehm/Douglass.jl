

mutable struct Stream
    s::String
    pos::Int64
end



# These keywords denote end of blocks
block_delimiters = ["if", "in", "using"]
function block_delimiter_symbol(c::String)
    if c == "if"
        return :block_delimiter_if
    elseif c == "in"
        return :block_delimiter_in
    elseif c == "using"
        return :block_delimiter_using
    else 
        error("$c : Not a block delimiter")
    end
end

word_delimiters = [' ', '\n', ',']
function delimiter_symbol(c::Char)
    if c == ' '
        return :delimiter_whitespace
    elseif c == '\n'
        return :delimiter_nl
    elseif c == ','
        return :delimiter_comma
    else
        error("Not a delimiter character.")
    end
end
function delimiter_symbol(c::String)
    if c == "//"
        return :delimiter_comment
    elseif c == ": "
        return :delimiter_colon
    else
        error("Not a delimiter string.") 
    end
end

par_openers = ['(', '[', '{']
par_closers = [')', ']', '}'] 
string_delimiters = ['"'] # we're not recognizing single quotes at this stage

# is `closer` a matching parentheses to `opener`?
function is_matching_closer(opener::Char, closer::Char)
    return (opener, closer) == ('(',')') ||
        (opener, closer) == ('[',']') ||
        (opener, closer) == ('{','}')
end

function is_keyword(s::AbstractString)
    return s ∈ keywords
end
function is_word_delimiter(c::Char)
    return c ∈ word_delimiters
end

# primitive parser functions
function parse_peek(s::Stream)
    return s.s[s.pos]
end
function parse_next(s::Stream)
    s.pos += 1
    return s.s[s.pos-1]
end
function parse_eof(s::Stream)
    return s.pos>length(s.s)
end
function flush_and_indicate(s::Stream)
    return "$(s.s)\n" * " "^(s.pos-1) * "^"
end

# get the string until the next delimiter
function get_word(s::Stream)
    ret_str = ""
    # open parentheses and strings
    open_parentheses = Vector{Char}()
    in_string = false
    delimiter = :delimiter_eof # change this if we hit another delimiter
    while !parse_eof(s)
        c = parse_next(s)
        if length(open_parentheses) == 0 && !in_string && is_word_delimiter(c)
            # parentheses/strings are balanced and we are facing a word delimiter
            delimiter = delimiter_symbol(c)
            break
        end
        if c == '/' && parse_peek(s) == '/'
            # comment
            delimiter = delimiter_symbol("//")
            parse_next(s)
            break
        elseif length(open_parentheses) == 0 && c == ':' && !parse_eof(s) && parse_peek(s) == ' '
            # end of the prefix
            delimiter = delimiter_symbol(": ")
            parse_next(s)
            break
        elseif c ∈ par_closers
            is_matching_closer(open_parentheses[end], c) || error("Douglass: parse error: unbalanced parentheses.\n$(flush_and_indicate(s))")
            pop!(open_parentheses)
        elseif c ∈ par_openers
            push!(open_parentheses, c)
        elseif c ∈ string_delimiters
            in_string = !in_string
        end 
        # append it
        ret_str = ret_str * c
    end
    if length(open_parentheses) > 0
        error("Douglass: parse error: unbalanced parentheses.\n$(flush_and_indicate(s))")
    end
    if in_string
        error("Douglass: parse error: unbalanced string quotes.\n$(flush_and_indicate(s))")
    end
    return ret_str, delimiter
end

function get_block(s::Stream)

    block_delimiter = :none
    ret_str = ""
    while block_delimiter == :none
        pos_before = s.pos
        str, word_delimiter = get_word(s)

        if str ∈ block_delimiters
            # end the block because we've hit a keyword
            block_delimiter = block_delimiter_symbol(str) 
            # all these keywords expect something afterwards, so throw error if there's nothing
            if word_delimiter != :delimiter_whitespace
                error("Douglass: parse error: premature end of input after keyword `$(str)`.\n$(flush_and_indicate(s))")
            end
        elseif (word_delimiter == :delimiter_nl) || (word_delimiter == :delimiter_comment) || (word_delimiter == :delimiter_eof)
            # the following end the line
            block_delimiter = :block_delimiter_eol
            ret_str = ret_str * str
        elseif word_delimiter == :delimiter_colon
            block_delimiter = :block_delimiter_colon
            ret_str = ret_str * str
        elseif word_delimiter == :delimiter_comma
            block_delimiter = :block_delimiter_comma
            ret_str = ret_str * str
        elseif word_delimiter == :delimiter_whitespace
            ret_str = ret_str * str * " " # and keep going
        end
    end

    return ret_str, block_delimiter

end



function parse(s::Stream)

    delimiter = :none
    level = 0 # this makes sure that the order of blocks is ok

    # first block is either the prefix or the command
    str, delimiter = get_block(s)
    if delimiter == :block_delimiter_colon
        # it's the prefix 
        prefix = parse_prefix(strip(str))
        # next one must be the main command
        str, delimiter = get_block(s)
        command, arguments = parse_main(strip(str))
    else 
        # it's the main part of the command
        # no prefix
        prefix = Prefix(nothing, nothing)
        command, arguments = parse_main(strip(str))
    end

    if delimiter != :block_delimiter_eol
        # next one is either if/in/using or go to options
        if delimiter == :block_delimiter_comma 
            # options 
            str, delimiter = get_block(s)
            filter = nothing
            use = nothing
            options = parse_options(str)
            if delimiter != :block_delimiter_eol 
                # we don't allow any extra block after the options
                error("Douglass: parse error: unexpected symbol.\n$(flush_and_indicate(s))")
            end
        else
            # if/in/using
            old_delimiter = delimiter
            str, delimiter = get_block(s)
            if old_delimiter == :block_delimiter_if
                filter = Meta.parse(str)
                use = nothing
            elseif old_delimiter == :block_delimiter_in
                error("Douglass: parse error: `in` block is currently not supported.")
            elseif old_delimiter == :block_delimiter_using
                filter = nothing
                use = str
            end
            # now the only valid delimiter is "," or EOL
            if delimiter == :block_delimiter_comma
                # options 
                str, delimiter = get_block(s)
                options = parse_options(str)
                if delimiter != :block_delimiter_eol 
                    # we don't allow any extra block after the options
                    error("Douglass: parse error: unexpected symbol.\n$(flush_and_indicate(s))")
                end
            elseif delimiter != :block_delimiter_eol
                error("Douglass: parse error: unexpected keyword.\n$(flush_and_indicate(s))")
            else
                # no options
                options = nothing
            end
        end
    else # no if/in/using or options after the main command
        filter = nothing 
        use = nothing
        options = nothing
    end

    println("***************************************************************")
    println("Parser debug output:")
    println("By:")
    @show prefix.by
    println("Sort:")
    @show prefix.sort
    println("Command:")
    @show command 
    println("Arguments:")
    @show arguments 
    println("Filter:")
    @show filter 
    println("Using:")
    @show use 
    println("Options:")
    @show options 
    println("***************************************************************")
    
    return Command(prefix.by, prefix.sort, command, arguments, filter, use, options)

end

function parse_prefix(str::AbstractString)
    s = Stream(strip(str),1)
    
    byvars = Vector{Symbol}()
    sortvars = Vector{Symbol}()

    str, delimiter = get_word(s)
    if str == "bysort"
        while delimiter == :delimiter_whitespace
            str, delimiter = get_word(s)
            if str[1] == '('
                # we're entering the sort part
                # assert format (<varlist>)
                (str[end] == ')') || error("Douglass: parse error: error parsing prefix. expecting ')'.\n$(flush_and_indicate(s))")
                vars = split(str[2:end-1]," ")
                sortvars = Symbol.(stripcolon.(vars[.!isempty.(vars)]))
                (delimiter == :delimiter_eof) || error("Douglass: parse error: error parsing prefix. expected end of line after ')'.\n$(flush_and_indicate(s))")
                break
            else
                # we're still in the 'by' part
                !isempty(strip(str)) && push!(byvars, Symbol(stripcolon(strip(str))))
            end
        end
        # Stata allows bysort without variables to sort by... not nice, but ok.
        # !isempty(sortvars) || error("Douglass: parse error: error parsing prefix. `bysort` expects a list of variables to sort by.\n$(flush_and_indicate(s))")
    
    elseif str == "by"
        (delimiter == :delimiter_whitespace) || error("Douglass: parse error: error parsing prefix. expecting list of variable names.\n$(flush_and_indicate(s))")
        while delimiter == :delimiter_whitespace
            str, delimiter = get_word(s)
            (str[1] != '(') || error("Douglass: parse error: `by` does not allow sorting. use `bysort`.\n$(flush_and_indicate(s))")
            !isempty(strip(str)) && push!(byvars, Symbol(stripcolon(strip(str))))
        end
    else 
        error("Douglass: parse error: error parsing prefix. prefix must be `by` or `bysort`.\n$(flush_and_indicate(s))")
    end
    return Prefix(byvars, sortvars)
end
# This function parses the <command> <arguments> part of the string.
# if the arguments are a sequence of strings separated by whitespaces where each of the strings starts with a ':', it's interpreted
# as a varlist and returned as a Vector{Symbol}, otherwise as an Expr
function parse_main(str::AbstractString)

    s = split(strip(str), " ", limit=2)
    if length(s)==1 
        # command only
        command = s[1]
        arguments = nothing
    else
        # command + arguments
        command = s[1]
        # remove all empty strings
        args = split(strip(s[2]), " ")
        args = args[.!(isempty.(args))]
        if all([args[i][1] == ':' for i=1:size(args,1)])
            # looks like it's a varlist... parse as Vector{Symbol}
            arguments = Symbol.([args[i][2:end] for i=1:size(args,1)])
        else
            # parse as Expr
            arguments = Meta.parse(s[2])
        end
    end

    return command, arguments
end

# takes an option string of the form "foo" or "foo(bar)" and parses it as a key, val pair
function parse_option(str::AbstractString)
    s = Stream(str,1)
    outkey = ""
    outval = ""
    inval = false
    while !parse_eof(s)
        c = parse_next(s)
        if c == '('
            inval = true
        elseif (inval==false) && (c == ')')
            error("Parse error: unexpected symbol encountered while parsing options.\n$(flush_and_indicate(s))")
        elseif (inval==true) && (c == ')')
            !parse_eof(s) && error("Parse error: unexpected symbol encountered while parsing options.\n$(flush_and_indicate(s))")
        elseif inval == false
            outkey = outkey * c
        elseif inval == true
            outval = outval * c
        end
    end
    if length(outkey)==0
        error("Parse error: invalid option string.\n$(flush_and_indicate(s))")
    end
    if length(outval)==0
        # no value, set to "true"
        outval = "true"
    end
    return outkey, outval
end

# options are being parsed in the following way:
#   `foo` results in an entry "foo" => true 
#   `foo(bar)` results in an entry "foo" => Meta.parse(bar)
function parse_options(str::AbstractString)
    s = Stream(str,1)
    out = Dict{String, Any}()
    while !parse_eof(s)
        word, del = get_word(s)
        if !isempty(strip(word))
            k, v = parse_option(strip(word))
            push!(out, k => Meta.parse(v))
        end
        if (del == :delimiter_colon) || (del == :delimiter_comma)
            error("Parse error: unexpected delimiter in options.\n$(flush_and_indicate(s))")
        end
    end
    return out
end

# This evaluates the $$ in the Stream.
# I hate this solution, but it's the best I could come up with.
function interp(s::Stream)

    ret_string = ""
    while !parse_eof(s)
        c = parse_next(s)
        if (c == '$') && !parse_eof(s) && parse_peek(s) == '$'
            !parse_eof(s) || error("Interpolation error: unexpected end of string.")
            parse_next(s)
            if (parse_peek(s) == '(')
                # go until next ')'
                parse_next(s)
                m = ""
                while true
                    c2 = parse_next(s)
                    if c2 == ')'
                        break
                    else 
                        m = m * c2
                    end
                    !parse_eof(s) || error("Interpolation error: unexpected end of string.")
                end
            else
                # go until next whitespace
                m = ""
                while true
                    c2 = parse_next(s)
                    if c2 == ' '
                        break
                    else 
                        m = m * c2
                    end
                    !parse_eof(s) || break
                end
            end
            ret_string = ret_string * string(Base.eval(Main,Symbol(m))) * ' '
        else
            ret_string = ret_string * c
        end
    end
    return ret_string
end

# This is supposed to be an simple parser for commands.
#
# The standard form is
#   [prefix]: <cmd> [expr] [if] [in] [using <filename>] [= <expr>] [, <options>]
#
#
#  Standard Stata syntax is
# cmd [varlist | namelist | anything]
# [if]
# [in]
# [using filename]
# [= exp]
# [weight]
# [, options]
#
# Stuff before the first ": " is considered the prefix
# Stuff after the first 
function parse(str::AbstractString)

    # First interpolate the $ (or $() ) expressions
    # I hate it, but I have not found a solution other than eval (or globals)
    stream = Stream(str,1)
    s_after_interpolation = interp(stream)
    println("After \$ parsing: $s_after_interpolation")

    stream = Stream(s_after_interpolation, 1)
    cmd = parse(stream)
end


# macro d_str(ex)
#     println("Entering d_str:")
#     println("$(typeof(ex))")
    
#     #return Expr(:macrocall, Symbol("@$(ex)"), "")
# end

# d"replace x = 1 if y == 2"

# d"""

# """

# s = Stream("bysort mygroup (mysort): gen x = 5",1)

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