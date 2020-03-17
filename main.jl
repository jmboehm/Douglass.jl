


using Douglass

using Tables
using DataFrames, RDatasets
using DataFramesMeta
using Test



include("src/douglass.jl")

# rename
df = dataset("datasets", "iris")
Douglass.rename(df, :SepalLength, :MyName)
@test names(df)[1] == :MyName

# gen (vector)
df = dataset("datasets", "iris")
Douglass.gen(df, :ct, collect(1:150))
@test df.ct ≈ collect(1:150) atol = 1e-4

# @gen! (expression)
df = dataset("datasets", "iris")
Douglass.@gen!(df, :mysum, :SepalLength + :SepalWidth)
@test df.mysum ≈ df.SepalLength .+ df.SepalWidth atol = 1e-4

# @replace! (expression)
df = dataset("datasets", "iris")
Douglass.@replace!(df, :SepalLength, 1.0)
@test df.SepalLength ≈ ones(Float64, 150) atol = 1e-4
df = dataset("datasets", "iris")
Douglass.@replace!(df, :PetalLength, :SepalLength + :SepalWidth)
@test df.PetalLength ≈ df.SepalLength .+ df.SepalWidth atol = 1e-4


squareme(x::Real) = x*x
Douglass.@gen(df, :mysum2, squareme.(:SepalLength))

Douglass.@gen(df, :mysum2, squareme.(:SepalLength))


x = @with(df, :SepalWidth + :SepalLength)


df = DataFrame(x = 1:3, y = [2, 1, 2])
x = [2, 1, 0]
df

@with(df, :y .+ 1)
a = @with(df, :x + x)


# --------

macro douglass(bysort::Expr, ex2::Symbol, options::Expr)
    @show bysort 
    @show ex2
    @show options
end

@douglass bysort(var1,var2) egen options(bla1,bla2)

macro douglass(ex::Expr...)
    @show ex
end
