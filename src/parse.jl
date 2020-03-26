
macro mymacro()
    println("You called my macro")
end

macro d_str(ex)
    println("Calling macro:")
    return Expr(:macrocall, Symbol("@$(ex)"), "")
end
d"mymacro"

mutable struct Stream
    s::String
    pos::Int64
end

# These keywords denote end of blocks
block_delimiters = [": ", "if", "in", "using", "=", "," ]

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
        elseif length(open_parentheses) == 0 && c == ':' && parse_peek(s) == ' '
            # enf of the prefix
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
        s, word_delimiter = get_word(s)
        if word_delimiter == :delimiter_nl

        elseif :delimiter_comma
    end

end

str = "bysort mygroup (myvar): egen var = mean(othervar) if thirdvar = 5, missing"
s = Stream(str, 1)

str2 = "bysort (var): gen"
s2 = Stream(str2, 1)
get_word(s2)
get_word(s2)


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

    # some rules:
    # we can always insert a space before and after ","
    # we 

    stream = Stream(str, 1)

end

# the prefix is the stuff before a ": "
function parse_prefix(prefix::AbstractString)

end




function read_next()

end

macro d_str(ex)
    println("Entering d_str:")
    println("$(typeof(ex))")
    
    #return Expr(:macrocall, Symbol("@$(ex)"), "")
end

d"replace x = 1 if y == 2"

d"""

"""

s = Stream("bysort mygroup (mysort): gen x = 5",1)

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