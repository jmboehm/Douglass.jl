


using Douglass

using Tables
using DataFrames, RDatasets
using DataFramesMeta
using Test



include("src/douglass.jl")

# @rename!
df = dataset("datasets", "iris")
Douglass.@rename!(df, :SepalLength, :MyName)
@test names(df)[1] == :MyName

# gen (vector)
df = dataset("datasets", "iris")
Douglass.gen(df, :ct, collect(1:150))
@test df.ct ≈ collect(1:150) atol = 1e-4

# @gen! (expression)
df = dataset("datasets", "iris")
Douglass.@generate!(df, :mysum, :SepalLength + :SepalWidth)
@test df.mysum ≈ df.SepalLength .+ df.SepalWidth atol = 1e-4

# @gen! (expression with if)
df = dataset("datasets", "iris")
Douglass.@generate!(df, :mysum, :SepalLength + :SepalWidth, :PetalLength .> 1.3)
@assert maximum(skipmissing(abs.(df.mysum .- (df.SepalLength .+ df.SepalWidth) ))) < 1e-4

# @replace! (expression)
df = dataset("datasets", "iris")
Douglass.@replace!(df, :SepalLength, 1.0)
@test df.SepalLength ≈ ones(Float64, 150) atol = 1e-4
df = dataset("datasets", "iris")
Douglass.@replace!(df, :PetalLength, :SepalLength + :SepalWidth)
@test df.PetalLength ≈ df.SepalLength .+ df.SepalWidth atol = 1e-4

# @drop_var! <varlist>
df = dataset("datasets", "iris")
Douglass.@drop_var!(df, [:SepalLength,:SepalWidth])
@assert :SepalLength ∉ names(df)
@assert :SepalWidth ∉ names(df)

# @keep_var! <varlist>
df = dataset("datasets", "iris")
Douglass.@keep_var!(df, [:SepalLength,:SepalWidth])
@test names(df) == [:SepalLength, :SepalWidth]

# @drop_if! <filter>
df = dataset("datasets", "iris")
Douglass.@drop_if!(df, :SepalLength .< 5.0)
@test all(df.SepalLength .>= 5.0)

# @keep_if! <filter>
df = dataset("datasets", "iris")
Douglass.@keep_if!(df, :SepalLength .< 5.0)
@test all(df.SepalLength .< 5.0)

# @assert_filter
df = dataset("datasets", "iris")
@test Douglass.@assert_filter(df, :SepalLength .< 2)
@test Douglass.@assert_filter(df, :SepalLength)

# @assert_vars_present
df = dataset("datasets", "iris")
@test Douglass.@assert_vars_present(df, [:SepalLength,:SepalWidth])

# @transform!
include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@transform!(df, [:sp], [:SepalLength], :mymean,  mean(:SepalLength), :SepalWidth .> 3.0, [] )
@test df[150,:mymean] === missing
@test df[149,:mymean] ≈ 6.80588 atol = 1e-4
include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@transform!(df, [:sp], [:SepalLength], :mymean,  mean(:SepalLength), :SepalWidth .> 3.0, [:fill] )
@test df[150,:mymean] ≈ 6.80588 atol = 1e-4
@test df[149,:mymean] ≈ 6.80588 atol = 1e-4

Douglass.@transform!(df, [:sp], [:SepalLength], :mymean2,  mean(:mymean), :SepalWidth .> 0.0, [] )


# @duplicates_drop!
include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@duplicates_drop!(df, [:sp])
@test df.SepalWidth ≈ [3.5;3.2;3.3] atol = 1e-4


squareme(x::Real) = x*x
Douglass.@gen(df, :mysum2, squareme.(:SepalLength))

Douglass.@gen(df, :mysum2, squareme.(:SepalLength))


x = @with(df, :SepalWidth + :SepalLength)


df = DataFrame(x = 1:3, y = [2, 1, 2])
x = [2, 1, 0]
df

@with(df, :y .+ 1)
a = @with(df, :x + x)

macro testthis(e...)
    return quote 
        println($e)
    end
end

macro testme(t::Symbol, e::Expr)
    esc(
        quote
            println($e)
        end
    )
end
@testme(df, Douglass.@generate!(df, :new, 1.0))

@testme df Douglass.@generate!(df, :new, 1.0)

include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)

Douglass.@bysort!(df, [:sp], [:SepalLength], Douglass.@generate!(_df, :x, 1.0))

using Statistics




    transform(x = mean(:SepalWidth))

include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
gd = groupby(df, [:sp])
gd2 = map(_df -> mean(_df.SepalLength), gd)

f = _df -> mean(_df.SepalLength)
 

gd = groupby(df, :sp)
for g in gd
    Douglass.@generate!(g, :x, 1.0)
end

include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
df[!,:mymean] = missings(Float64, size(df,1))
x_thread = @linq df |>
    where(:SepalWidth .> 3.0) |>
    by(:sp, meanWidth = mean(:SepalLength)) 



gd = groupby(df, :sp)
my_f = _df -> @byrow! _df begin
    @newcol x::Array{Float64}
    :x = mean(:SepalLength)
end
by(df, [:sp], my_f )


include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@gen_byrow2!(df, [:sp], [:SepalLength], :mymean, Float64, :SepalWidth[i]*:SepalLength[i], :PetalLength[i] > 3.0, [])



Douglass.@drop!(df, [:SepalWidth :SepalLength])

@testthis bysort var1 (var2): egen bla = mean(x) on x .=5, missing
println(bysort var1 (var2): egen bla = mean(x) if x .=5)

macro d_str(p)
    return quote 
        println($p)
    end
end

d"gen x = 1"
d"""
gen x = 1
replace x = 2
"""


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


a = DataFrame(firm = [1,1,1,1,2,2,2,2], worker = [1,1,2,2,3,3,4,4], year = [2000,2001,2000,2001,2000,2001,2000,2001], wage = 20 .+ 20.0 .* rand(Float64,8))
allowmissing!(a,[:wage])
a[[2,3,6],:wage] .= missing
a

gd = groupby(a, [:firm])
@transform(gd, averageWage = mean(skipmissing(:wage)))

a[!,:wageIncrease] = missings(Float64,size(a,1))
sort!(a, [:worker, :year])
f = _df -> @with _df begin
    for i = 2:size(_df,1)
        :wageIncrease[i] = :wage[i] - :wage[i-1]
    end
    _df
end
by(a, [:worker], f)

sort!(a, [:wage])