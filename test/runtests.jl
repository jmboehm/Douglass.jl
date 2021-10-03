using Douglass

tests = ["Douglass.jl"
		 ]

println("Running tests:")

for test in tests
	try
		include(test)
		println("\t\033[1m\033[32mPASSED\033[0m: $(test)")
	 catch e
	 	println("\t\033[1m\033[31mFAILED\033[0m: $(test)")
	 	showerror(stdout, e, backtrace())
	 	rethrow(e)
	 end
end

# don't do repl test on unix-- TODO improve this
if !Sys.isunix()
	try
		include("repl.jl")
		println("\t\033[1m\033[32mPASSED\033[0m: REPL.jl")
	 catch e
	 	println("\t\033[1m\033[31mFAILED\033[0m: REPL.jl")
	 	showerror(stdout, e, backtrace())
	 	rethrow(e)
	 end
end