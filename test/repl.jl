using REPL
import REPL: Terminals
using Douglass

mutable struct FakeTerminal <: Terminals.UnixTerminal
    in_stream::Base.IO
    out_stream::Base.IO
    err_stream::Base.IO
    hascolor::Bool
    raw::Bool
    FakeTerminal(stdin,stdout,stderr,hascolor=true) =
        new(stdin,stdout,stderr,hascolor,false)
end

Terminals.hascolor(t::FakeTerminal) = t.hascolor
Terminals.raw!(t::FakeTerminal, raw::Bool) = t.raw = raw
Terminals.size(t::FakeTerminal) = (24, 80)

# fake repl

input = Pipe()
output = Pipe()
err = Pipe()
Base.link_pipe!(input, reader_supports_async=true, writer_supports_async=true)
Base.link_pipe!(output, reader_supports_async=true, writer_supports_async=true)
Base.link_pipe!(err, reader_supports_async=true, writer_supports_async=true)

repl = REPL.LineEditREPL(FakeTerminal(input.out, output.in, err.in), true)

repltask = @async begin
    REPL.run_repl(repl)
end

send_repl(x, enter=true) = write(input, enter ? "$x\n" : x)

function read_repl(io::IO, x)
    cache = Ref{Any}("")
    read_task = @task cache[] = readuntil(io, x)
    t = Base.Timer((_) -> Base.throwto(read_task,
                ErrorException("Expect \"$x\", but wait too long.")), 5)
    schedule(read_task)
    fetch(read_task)
    close(t)
    cache[]
end

check_repl_stdout(x) = length(read_repl(output, x)) > 0
check_repl_stderr(x) = length(read_repl(err, x)) > 0


# waiting for the repl
send_repl("using Douglass")
send_repl("df = DataFrame(x = collect(1:3))")
send_repl("Douglass.set_active_df(:df)")

Douglass.DouglassPrompt.repl_init(repl)

send_repl("`", false)
@test check_repl_stdout("Douglass> ")

send_repl("gen :y = 1.0")
send_repl("\b", false)

send_repl("mean(df.y)")
@test check_repl_stdout("1.0")