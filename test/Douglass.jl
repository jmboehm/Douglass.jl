using Revise
using RDatasets, Test

include("src/Douglass.jl")

# 1.) Testing command macros

# @rename!
# df = dataset("datasets", "iris")
# Douglass.@rename!(df, :SepalLength, :MyName)
# @test names(df)[1] == :MyName

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

# @gen! (expression with by and if)
df = dataset("datasets", "iris")
Douglass.@generate_byrow!(df, [:Species], [:SepalLength], :mysum, Float64, :SepalLength[i] + :SepalWidth[i], :PetalLength[i] .> 1.3)
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
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@transform!(df, [:sp], [:SepalLength], :mymean,  mean(:SepalLength), :SepalWidth .> 3.0, [] )
@test df[150,:mymean] === missing
@test df[149,:mymean] ≈ 6.80588 atol = 1e-4

df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@transform!(df, [:sp], [:SepalLength], :mymean,  mean(:SepalLength), :SepalWidth .> 3.0, [:fill] )
@test df[150,:mymean] ≈ 6.80588 atol = 1e-4
@test df[149,:mymean] ≈ 6.80588 atol = 1e-4

# @duplicates_drop!
include("src/douglass.jl")
df = dataset("datasets", "iris")
df.sp = categorical(df.Species)
Douglass.@duplicates_drop!(df, [:sp])
@test df.SepalWidth ≈ [3.5;3.2;3.3] atol = 1e-4


# 2.) Testing the interface

include("src/parse.jl")

str = "bysort mygroup1 mygroup2 ( myvar1 myvar2 ): egen var = mean(othervar) if thirdvar = 5, missing"
s = Stream(str, 1)
str, del = get_block(s)
p = parse_prefix(str)
str, del = get_block(s)
p = parse_main(str)


str = "by mygroup1 mygroup2: egen var = mean(othervar) if thirdvar = 5, missing"
s = Stream(str, 1)
str, del = get_block(s)
p = parse_prefix(str)

# some tests

include("src/Douglass.jl")
df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
d"by :Species : generate :x = :SepalWidth + :PetalLength"
@test (:x ∈ names(df))
@test df[1,:x] ≈ 4.9 atol = 1e-4
select!(df, Not(:x))    # this drops the column, and we can re-start
d"bysort :Species (:SepalLength) : generate :x = :SepalWidth + :PetalLength if :PetalLength .> 1.3"
@test ismissing(df[1,:x])
@test sum(skipmissing(df.x)) ≈ 972.3 atol = 1e-4
#select!(df, Not(:x)) 
d"bysort :Species (:SepalLength) : generate :y = 99 if :PetalLength .> 1.3"
@test (eltype(df.y) == Union{Missing, Int64})
# this should keep :y as a Int64
d"bysort :Species (:SepalLength) : replace :y = 99.0 if :SepalLength > 7.8"
@test (eltype(df.y) == Union{Missing, Int64})
select!(df, Not(:y))
# Test the generate without by/bysort
d"gen :z = 1.0"
@test (:z ∈ names(df))
@test df[1,:z] == 1.0
select!(df, Not(:z))
d"generate :z = :SepalWidth + :PetalLength"
@test sum(skipmissing(df.z)) ≈ 1022.3  atol = 1e-4
select!(df, Not(:z))
d"gen :z = :SepalWidth + :PetalLength if :PetalWidth > 1.8"
@test sum(skipmissing(df.z)) ≈ 295.9  atol = 1e-4

Douglass.@use(df)
Douglass.@use df

d" drop :SepalWidth :SepalLength"
d" drop  :SepalWidth "
d" drop  :SepalWidth :"

d"drop [:SepalLength, :SepalWidth]"

d"drop [:SepalLength, :SepalWidth]"

d"drop if :PetalLength .< 3.0"

d"keep"

d"keep if :PetalLength .< 3.0"

d"sort [:SepalLength, :SepalWidth]"

df = dataset("datasets", "iris")
d"by mygroup1 mygroup2: egen :var = mean(:othervar) if thirdvar .== 5, missing"
d"egen"

a = :(:x = :SepalWidth + :PetalLength)

@with(df, :SepalWidth[1] + :PetalLength[1] )

dump(:(Mymodule.@mymacro) )
