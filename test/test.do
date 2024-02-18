// This file uses David Roodman's julia.ado to test Douglass from the Stata side.
//
// See https://github.com/droodman/julia.ado for more information on julia.ado.

clear

// Run a "Hello World" to see that julia.ado works 
jl: "Hello world!"

// install the required packages
jl: import Pkg; Pkg.add(["RDatasets", "Revise", "DataFrames", "DataFramesMeta"])
jl: import Pkg; Pkg.add(url="https://github.com/jmboehm/Douglass.jl")
// load packages
jl: using Douglass, RDatasets, Test, DataFrames, DataFramesMeta

// load dataset in julia, and bring to Stata
jl: df = dataset("datasets", "iris")	
jl GetVarsFromDF , source(df) replace

