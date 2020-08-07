
# # *******************

# Douglass.@use(df)
# Douglass.@use df

# d" drop :SepalWidth :SepalLength"
# d" drop  :SepalWidth "
# d" drop  :SepalWidth :"

# d"drop [:SepalLength, :SepalWidth]"

# d"drop [:SepalLength, :SepalWidth]"

# d"drop if :PetalLength .< 3.0"

# d"keep"

# d"keep if :PetalLength .< 3.0"

# d"sort [:SepalLength, :SepalWidth]"

# df = dataset("datasets", "iris")
# d"by mygroup1 mygroup2: egen :var = mean(:othervar) if thirdvar .== 5, missing"
# d"egen"

# a = :(:x = :SepalWidth + :PetalLength)

# Douglass.@with(df, :SepalWidth[1] + :PetalLength[1] )

# dump(:(Mymodule.@mymacro) )



# # string interpolation
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)

# name = "myone"
# d"gen :$$name = 1.0"
# d"gen :$$(name) = 1.0"

# m"gen :x = $(one)"

# name = :x
# d"gen $name = :SepalLength"


# ex = quote
#     :x::Float64 = :y .+ :z
#     drop :x
# end
# dump(ex)


# # ***************
# # egen with by and if
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)
# using Statistics

# d"gen :row = _n"
# d"bysort :Species (:SepalLength) : egen :x = mean(:PetalWidth) if :SepalWidth .< 3.4"
# sort!(df, :row)

# d"drop :x"
# d"bysort :Species (:SepalLength) : egen :x = :SepalLength if :SepalWidth .< 3.4"

# d"bysort :Species (:SepalLength) : egen :x = 1.0 if :SepalWidth .< 3.4"

# e = :(:SepalLength .+ :SepalWidth )
# dump(e)

# d"bysort :Species (:SepalLength) : egen :x = :SepalLength .+ mean(:PetalLength) if :PetalWidth .> 2.0"

# # egen with by but not if
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)
# using Statistics

# d"bysort :Species (:SepalLength) : egen :x = mean(:PetalWidth)"
# d"bysort :Species (:SepalLength) : erep :x = mean(:SepalLength)"


# # speed test

# vecr1 = rand(Float64, 1_000_000)
# vecr2 = rand(Float64, 1_000_000)
# vecr3 = Int64.(floor.(100.0 .*rand(Float64, 1_000_000)))

# df = DataFrame(x = vecr1, y = vecr2, g = vecr3)
# categorical!(df,:g)
# Douglass.set_active_df(:df)
# d"bysort :g (:x) : egen :z::Float64 = mean(:y) if :x .< 1000.0"
# d"drop :z"


# # parsing

# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)

# d"bysort :Species (:SepalLength) : gen :z = 1.0 if :SepalLength .< 1000.0, option1 option2(false) option3(:x .+ :y)"

# # replace without by
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)

# d"gen :x = _n"
# d"replace :x = _n + 1"
# d"replace :x = _n + 10 if _n<3 "



# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)

# d"rename :SepalLength :SomethingBetter"




# # cheatsheet
# macroexpand(Main, :(@d_str("rename :SepalLength :SomethingBetter")))
# macroexpand(Main, :(@d_str("bysort :Species (:SepalLength) : gen :z = 1.0 if :SepalLength .< 1000.0")))


# # merge

# # 1:1
# include("src/Douglass.jl")
# people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
# jobs = DataFrame(ID = [20, 40], Job = ["Lawyer", "Doctor"])
# Douglass.set_active_df(:people)
# d"merge_11 :ID using jobs"

# people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
# jobs = DataFrame(ID = [20, 60], Job = ["Lawyer", "Astronaut"])
# Douglass.set_active_df(:people)
# d"merge_11 :ID using jobs"

# # multiple keys
# people = DataFrame(ID = [20, 40], Birthday = ["1980-01-01", "1970-01-01"], Name = ["John Doe", "Jane Doe"])
# jobs = DataFrame(ID = [20, 40], Birthday = ["1980-01-01", "1970-01-01"], Job = ["Lawyer", "Doctor"])
# Douglass.set_active_df(:people)
# d"merge_11 :ID :Birthday using jobs"

# # 1:m
# people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
# jobs = DataFrame(ID = [20, 20, 60], Job = ["Lawyer", "Economist", "Astronaut"])
# Douglass.set_active_df(:people)
# d"merge_1m :ID using jobs"

# # m:1
# people = DataFrame(ID = [20, 40, 40], Name = ["John Doe", "Jane Doe", "The CEO"])
# jobs = DataFrame(ID = [20, 40, 60], Job = ["Lawyer", "Doctor", "Astronaut"])
# Douglass.set_active_df(:people)
# d"merge_m1 :ID using jobs"


# # reshape

# # with one variable
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)
# df.id = collect(1:(size(df,1)))
# select!(df,Not([:PetalLength,:PetalWidth]))
# d"reshape_long :Sepal , i(:id) j(:Var)"
# @test :Var ∈ propertynames(df)
# @test :Sepal ∈ propertynames(df)
# @test size(df,1) == 300
# d"reshape_wide :Sepal , i(:id) j(:Var)"
# @test :SepalLength ∈ propertynames(df)
# @test :SepalWidth ∈ propertynames(df)
# @test size(df,1) == 150
# df2 = dataset("datasets", "iris")
# for v in [:SepalLength, :SepalWidth]
#     @test all(df[!,v] .== df2[!,v])
# end

# # with two variables
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)
# df.id = collect(1:(size(df,1)))

# d"reshape_long :Sepal :Petal, i(:id) j(:Var)"
# @test :Var ∈ propertynames(df)
# @test :Sepal ∈ propertynames(df)
# @test :Petal ∈ propertynames(df)
# @test size(df,1) == 300
# d"reshape_wide :Sepal :Petal, i(:id) j(:Var)"
# @test :SepalLength ∈ propertynames(df)
# @test :SepalWidth ∈ propertynames(df)
# @test :PetalLength ∈ propertynames(df)
# @test :PetalWidth ∈ propertynames(df)
# @test size(df,1) == 150
# df2 = dataset("datasets", "iris")
# for v in [:SepalLength, :SepalWidth, :PetalLength, :PetalWidth]
#     @test all(df[!,v] .== df2[!,v])
# end

# # reshape

# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)

# df.id = collect(1:(size(df,1)))
# #df = stack(df, [:SepalLength, :SepalWidth], :Species)
# df = stack(df, Not([:Species, :id]))

# d"reshape_wide :value , i(:id) j(:variable)"

# macroexpand(Main, :(@d_str("reshape_wide :value , i(:id) j(:variable)")))

# df.value2 = df.value .+ 2.0
# df
# d"reshape_wide :value :value2 , i(:id) j(:variable)"

# # wide to long:
# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)
# df.id = collect(1:(size(df,1)))
# df
# #               all that are Stub*        i               j                given by `Stub`
# stack(df, [:SepalLength, :SepalWidth], [:id], variable_name=:VarIndex, value_name=:Sepal)

# d"reshape_long :Sepal, i(:id) j(:Var)"

# d"reshape_long :Sepal :Petal, i(:id) j(:Var)"

# # Examples from the Readme.md

# using Douglass, RDatasets
# df = dataset("datasets", "iris")
# # set the active DataFrame
# Douglass.set_active_df(:df)

# # create a variable `z` that is the sum of `SepalLength` and `SepalWidth`, for each row
# d"gen :z = :SepalLength + :SepalWidth"
# # replace `z` by the row index for the first 10 observations
# d"replace :z = _n if _n <= 10"
# # drop a variable
# d"drop :z"
# # construct the within-group mean for a subset of the observations
# d"bysort :Species : egen :z = mean(:SepalLength) if :SepalWidth .> 3.0"


# include("src/Douglass.jl")
# df = dataset("datasets", "iris")
# Douglass.set_active_df(:df)
# df.id = collect(1:(size(df,1)))

# d"reshape_long :Sepal :Petal, i(:id) j(:Var)"
# d"reshape_wide :Sepal :Petal, i(:id) j(:Var)"

# ------ BENCHMARK ---------

# using DataFrames, Random, BenchmarkTools
# using Douglass

# rng = MersenneTwister(12345)

# # This is Mathieu Gomez's setup for benchmarking FixedEffectModels
# N = 1_000_000
# K = 100
# id1 = rand(rng,1:div(N, K), N)
# id2 = rand(rng, 1:K, N)
# x1 = 5 * cos.(id1) + 5 * sin.(id2) + randn(N)
# x2 =  cos.(id1) +  sin.(id2) + randn(N)
# y= 3 .* x1 .+ 5 .* x2 .+ cos.(id1) .+ cos.(id2).^2 .+ randn(N)

# df = DataFrame(id1 = categorical(id1), id2 = categorical(id2), x1 = x1, x2 = x2, y = y)
# allowmissing!(df)

# df.x2[rand(rng, 1:10,N) .> 8] .= missing
# sort!(df, [:id2, :id1])


# set_active_df(:df)
# @time d"gen :z = :x1 + :x2"
# @time d"drop :z"

# @btime begin
#     d"gen :z = :x1 + :x2"
#     d"drop :z"
# end

# @btime begin
#     d"bysort :id2 (:id1): egen :z = mean(:x1)"
#     d"drop :z"
# end

# @time begin
#     d"egen :z = mean(:x1)"
#     d"drop :z"
# end

# @time d"gen :z = 0.0"
# @time d"replace :z = :x1 + :x2"
# @time d"drop :z"

# @time d"gen :z = 0.0"
# @time d"bysort :id2 (:id1): egen :z = mean(:x1)"
# @time d"drop :z"

# @time d"bysort :id2 (:id1): egen :z::Float64 = mean(:x1)"
# @time d"drop :z"

# @time df2 = combine(x -> mean(x) , groupby(df,[:id2], sort=false, skipmissing = false ))

# @time by(df, [:id1], :, :x1 => mean)

# df[:z] .= 0.0

# @time d"drop :z"

# d"bysort :id2 (:id1): egen :z = mean(:x2) if ismissing(:x2)"

# d"drop :z"

# @time transform!(groupby(df, [:id2], sort=false, skipmissing = true ), :x1 => mean => :z)

# function myfun2(args...)
#     return cor(args[1],args[2])
# end


# @time transform!(groupby(df, [:id2], sort=false, skipmissing = true ), [:x1,:x2] => cor => :z)
# @time transform!(groupby(df, [:id2], sort=false, skipmissing = true ), [:x1,:y] => cor => :z)

# @time transform!(groupby(df, [:id2], sort=false, skipmissing = true ), [:x1,:y] => myfun2 => :z)

# using Pipe

# @time @pipe df |> groupby(_, :id2) |> transform!(_, :x2 => mean => :z)
# d"drop :z"

# @time @pipe df |> filter(:y => x -> x>0.0, _) |> groupby(_, :id2) |> transform!(_, :x1 => mean => :z)
# d"drop :z"


# function m_f(x)
#     a = x[.!ismissing.(x)]
#     a = a[a .> 0]
#     return mean(a)
# end

# @time transform!(groupby(df, [:id2], sort=false, skipmissing = true ), [:x1,:y] => myfun2 => :z)

# # @time @pipe df |> groupby(_, :id2) |> transform!(_, :x2 => mean => :z))


# @time transform!(groupby(df, [:id2], sort=false, skipmissing = true ), :x2 => m_f => :z )

# d"drop :z"

# dump( :( a + cor(:x1, :x2)))
# dump( :(args[1]))
# dump( :( args[1][2] ))

# a = [ [1, 2] , [3,4]]
# a[1][2]

# using MacroTools

# ex = :( cor(:x1, :x2, :x1) )
# qn_vec = Vector{QuoteNode}()
# replace_QuoteNodes!(ex, :args, qn_vec)

# ex
# qn_vec


# include("src/Douglass.jl")

# using Revise

# using DataFrames, Random, BenchmarkTools
# using Douglass

# rng = MersenneTwister(12345)

# # This is Mathieu Gomez's setup for benchmarking FixedEffectModels
# N = 1_000_000
# K = 100
# id1 = rand(rng,1:div(N, K), N)
# id2 = rand(rng, 1:K, N)
# x1 = 5 * cos.(id1) + 5 * sin.(id2) + randn(N)
# x2 =  cos.(id1) +  sin.(id2) + randn(N)
# y= 3 .* x1 .+ 5 .* x2 .+ cos.(id1) .+ cos.(id2).^2 .+ randn(N)

# df = DataFrame(id1 = categorical(id1), id2 = categorical(id2), x1 = x1, x2 = x2, y = y)
# allowmissing!(df)

# df.x2[rand(rng, 1:10,N) .> 8] .= missing
# sort!(df, [:id2, :id1])


# set_active_df(:df)
# @time d"gen :z = :x1 + :x2"
# @time d"drop :z"

# include("src/Douglass.jl")

# @time begin
#     d"bysort :id2 (:id1): egen :z = mean(:x2) if .!ismissing.(:x2) "
#     d"drop :z"
# end

# @time begin
#     d"bysort :id2 (:id1): egen :z = mean(:y) "
#     d"drop :z"
# end

# @time begin
#     d"egen :z = mean(:x2) if .!ismissing.(:x2) "
#     d"drop :z"
# end

# @time begin
#     d"egen :z = mean(:y) "
#     d"drop :z"
# end


# using Statistics
# @time begin
#     d"bysort :id2 (:id1): egen2 :z = cor(:x1, :x2) if .!ismissing.(:x2)"
#     d"drop :z"
# end

# @time d"bysort :id2 (:id1): egen :z = mean(:x2) if .!ismissing.(:x2) "

# d"bysort :id2 (:id1): egen2 :z = cor(:x1, :x2) if 0+1"

# @time d"bysort :id2 (:id1): egen :z = mean(:x1) if 1+1"


# @time begin
#     d"bysort :id2 (:id1): egen :z = :x1 .+ :x2 if :x1 .> 0.0 "
#     d"drop :z"
# end


# @time begin
#     d"bysort :id2 (:id1): egen :z = :x1 .+ :x2 if :x1 .> 0.0 "
#     d"drop :z"
# end

# include("src/Douglass.jl")
# @time begin
#     d"bysort :id2 (:id1) : erep :y = mean(:x1) if :x1 .> 0.0"
# end

# @time begin
#     d"bysort :id2 (:id1) : erep :y = mean(:x1) "
# end

# @time begin
#     d"erep :y = mean(:x1) if :x1 .> 0.0"
# end

# @time begin
#     d"erep :y = mean(:x1)"
# end


# a = Vector{QuoteNode}()
# push!(a, QuoteNode(:x1))
# push!(a, QuoteNode(:y))
# Symbol.(a)
# println("$(Symbol.(a))")
