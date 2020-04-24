# implements a REPL mode

# most of this is lifted from RCall. Thanks guys!

module DouglassPrompt 

    using REPL
    import REPL: REPL, LineEdit

    # import ..Douglass:
    #     @d_str,
    #     parse

    function simple_showerror(io::IO, er)
        Base.with_output_color(:red, io) do io
            print(io, "ERROR: ")
            showerror(io, er)
            println(io)
        end
    end

    function parse_status(script::String)
        status = :ok
        try
            #render(script)
        catch ex
            if isa(ex, DParseIncomplete)
                status = :incomplete
            else
                status = :error
            end
        end
        status
    end

    function repl_eval(script::String, stdout::IO, stderr::IO)
        try
#            @d_str(script)
        catch ex
            # TODO check here for specific error types (parse error etc)
            simple_showerror(stderr, ex)
        finally
            return nothing
        end
    end
        

    function bracketed_paste_callback(s, o...)
        input = LineEdit.bracketed_paste(s)
        sbuffer = LineEdit.buffer(s)
        curspos = position(sbuffer)
        seek(sbuffer, 0)
        shouldeval = (bytesavailable(sbuffer) == curspos && !occursin(UInt8('\n'), sbuffer))
        seek(sbuffer, curspos)
        if curspos == 0
            # if pasting at the beginning, strip leading whitespace
            input = lstrip(input)
        end
    
        if !shouldeval
            LineEdit.edit_insert(s, input)
            return
        end
    
        LineEdit.edit_insert(sbuffer, input)
        input = String(take!(sbuffer))
    
        m = sizeof(input)
        oldpos = 1
        nextpos = 0
        # parse the input line by line
        while nextpos < m
            next_result = findnext("\n", input, nextpos + 1)
            if next_result == nothing
                nextpos = m
            else
                nextpos = next_result[1]
            end
            block = input[oldpos:nextpos]
            status = parse_status(block)
    
            if status == :error  || (status == :incomplete && nextpos == m) ||
                    (nextpos == m && !endswith(input, '\n'))
                # error / continue and the end / at the end but no new line
                LineEdit.replace_line(s, input[oldpos:end])
                LineEdit.refresh_line(s)
                break
            elseif status == :incomplete && nextpos < m
                continue
            end
    
            if !isempty(strip(block))
                # put the line on the screen and history
                LineEdit.replace_line(s, strip(block))
                LineEdit.commit_line(s)
                # execute the statement
                terminal = LineEdit.terminal(s)
                REPL.raw!(terminal, false) && LineEdit.disable_bracketed_paste(terminal)
                LineEdit.mode(s).on_done(s, LineEdit.buffer(s), true)
                REPL.raw!(terminal, true) && LineEdit.enable_bracketed_paste(terminal)
            end
            oldpos = nextpos + 1
        end
        LineEdit.refresh_line(s)
    end

    function create_d_repl(repl, main)
        d_mode = LineEdit.Prompt("Douglass> ";
            prompt_prefix=Base.text_colors[:cyan],
            prompt_suffix=main.prompt_suffix,
            sticky=true)
    
        hp = main.hist
        hp.mode_mapping[:d] = d_mode
        d_mode.hist = hp
        #d_mode.complete = DCompletionProvider(repl)
        # d_mode.on_enter = main.on_enter
        # d_mode.on_enter = (s) -> begin
        #     status = parse_status(String(take!(copy(LineEdit.buffer(s)))))
        #     status == :ok || status == :error
        # end
        main_f = main.on_done
        d_mode.on_done = (s, buf, ok) -> begin
            mybuf = IOBuffer(sizehint = buf.size + 3)
            write(mybuf, "d\"" * read(buf, String) * "\"")
            main_f(s, mybuf, ok)
        end
    
        bracketed_paste_mode_keymap = Dict{Any,Any}(
            "\e[200~" => bracketed_paste_callback
        )
    
        search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
        prefix_prompt, prefix_keymap = LineEdit.setup_prefix_keymap(hp, d_mode)
    
        mk = REPL.mode_keymap(main)
        # ^C should not exit prompt
        delete!(mk, "^C")
    
        b = Dict{Any,Any}[
            bracketed_paste_mode_keymap,
            skeymap, mk, prefix_keymap, LineEdit.history_keymap,
            LineEdit.default_keymap, LineEdit.escape_defaults
        ]
        d_mode.keymap_dict = LineEdit.keymap(b)
    
        d_mode
    end
    
    function repl_init(repl)
        mirepl = isdefined(repl,:mi) ? repl.mi : repl
        main_mode = mirepl.interface.modes[1]
        d_mode = create_d_repl(mirepl, main_mode)
        push!(mirepl.interface.modes,d_mode)
    
        d_prompt_keymap = Dict{Any,Any}(
            '`' => function (s,args...)
                if isempty(s) || position(LineEdit.buffer(s)) == 0
                    buf = copy(LineEdit.buffer(s))
                    LineEdit.transition(s, d_mode) do
                        LineEdit.state(s, d_mode).input_buffer = buf
                    end
                else
                    LineEdit.edit_insert(s, '$')
                end
            end
        )
    
        main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, d_prompt_keymap);
        nothing
    end

    function repl_inited(repl)
        mirepl = isdefined(repl,:mi) ? repl.mi : repl
        any(:prompt in fieldnames(typeof(m)) && m.prompt == "Douglass> " for m in mirepl.interface.modes)
    end

end