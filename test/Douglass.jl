using Revise

using Douglass
using RDatasets, Test
using DataFrames, DataFramesMeta

df = dataset("datasets", "iris")
Douglass.@use(df)

# `gen` without anything else ****************************************************************************
d"generate :x = 1.0"
@test all(df.x .== 1.0)
select!(df, Not(:x))
d"generate :x = :SepalLength"
@test all(df.x .== df.SepalLength)
select!(df, Not(:x))
d"generate :x = :SepalWidth + :PetalLength"
@test (:x ∈ propertynames(df))
@test df[1,:x] ≈ 4.9 atol = 1e-4
select!(df, Not(:x))    # this drops the column, and we can re-start
d"generate :x = :SepalWidth + :PetalLength if :PetalLength .> 1.3"
@test all((df.x .== df.SepalWidth .+ df.PetalLength) .| (df.PetalLength .<= 1.3))
@test sum(skipmissing(df.x)) ≈ 972.3 atol = 1e-4
#select!(df, Not(:x)) 
d"generate :y = 99 if :PetalLength .> 1.3"
@test (eltype(df.y) == Union{Missing, Int64})
d"generate :x2 = _n"
@test (df.x2[1] == 1) && (df.x2[end] == 150)
select!(df, Not(:x2))
# can we use stuff from julia?
d"generate :z = rand(Float64)"

# `gen` with `bysort` *************************************************************************
df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"by :Species : generate :x = 1.0"
@test all(df.x .== 1.0)
select!(df, Not(:x))
d"by :Species : generate :x = :SepalLength"
@test all(df.x .== df.SepalLength)
select!(df, Not(:x))
d"by :Species : generate :x = :SepalWidth + :PetalLength"
@test (:x ∈ propertynames(df))
@test df[1,:x] ≈ 4.9 atol = 1e-4
select!(df, Not(:x))    # this drops the column, and we can re-start
d"bysort :Species (:SepalLength) : generate :x = :SepalWidth + :PetalLength if :PetalLength .> 1.3"
@test ismissing(df[1,:x])
@test sum(skipmissing(df.x)) ≈ 972.3 atol = 1e-4
#select!(df, Not(:x)) 
d"bysort :Species (:SepalLength) : generate :y = 99 if :PetalLength .> 1.3"
@test (eltype(df.y) == Union{Missing, Int64})
d"by :Species : generate :x2 = _n"
@test (df.x2[1] == 1) && (df.x2[end] == 50)
select!(df, Not(:x2))
# this should keep :y as a Int64
d"bysort :Species (:SepalLength) : replace :y = 99.0 if :SepalLength > 7.8"
@test (eltype(df.y) == Union{Missing, Int64})
d"gen :z = 0.0"
d"bysort :Species (:SepalLength) : replace :z = :x[_n - 2]"
sort!(df, [:Species, :SepalLength])
select!(df, Not(:y))
# Test the generate without by/bysort
select!(df, Not(:z))
d"gen :z = 1.0"
@test (:z ∈ propertynames(df))
@test df[1,:z] == 1.0
select!(df, Not(:z))
d"generate :z = :SepalWidth + :PetalLength"
@test sum(skipmissing(df.z)) ≈ 1022.3  atol = 1e-4
select!(df, Not(:z))
d"gen :z = :SepalWidth + :PetalLength if :PetalWidth > 1.8"
@test sum(skipmissing(df.z)) ≈ 295.9  atol = 1e-4
d"gen :z2 = _n"
d"drop :z2"
@test :z2 ∉ propertynames(df)
d"gen :z2 = :SepalLength"

# `drop` *************************************************************************

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"drop :SepalLength"
@test :SepalLength ∉ propertynames(df)
d"drop :PetalWidth :PetalLength"
@test :PetalWidth ∉ propertynames(df)
@test :PetalLength ∉ propertynames(df)

d"drop if :SepalWidth > 3.0"
@test size(df, 1) == 83
d"drop if _n > 10"
@test size(df, 1) == 10
d"drop if _n < _N / 2"
@test size(df, 1) == 6

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
d"bysort :Species : drop if :SepalLength == 5.1"
@test size(df,1) == 141
d"bysort :Species : drop if _n > 20"
@test size(df,1) == 60

# `keep` *************************************************************************


df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"keep :SepalLength :SepalWidth"
@test :PetalWidth ∉ propertynames(df)
d"keep if :SepalWidth > 3.1"
@test size(df,1) == 56
d"keep if _n <= 10"
@test size(df,1) == 10

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
d"bysort :Species : keep if :SepalLength != 5.1"
@test size(df,1) == 141
d"bysort :Species : keep if _n <= 20"
@test size(df,1) == 60

# `egen` *************************************************************************

# with `by` and `if`

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
using Statistics

d"bysort :Species (:SepalLength) : egen :x = mean(:PetalWidth) if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))
d"bysort :Species (:SepalLength) : egen :x = :SepalLength if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))
d"bysort :Species (:SepalLength) : egen :x = 1.0 if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))

# with `by` but not `if`

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
using Statistics

d"bysort :Species (:SepalLength) : egen :x = mean(:PetalWidth) "
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))
d"bysort :Species (:SepalLength) : egen :x = :SepalLength"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))
d"bysort :Species (:SepalLength) : egen :x = 1.0 "
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))

# without `by` but with `if`

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
using Statistics

d"egen :x = mean(:PetalWidth) if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))
d"egen :x = :SepalLength if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))
d"egen :x = 1.0 if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
select!(df, Not([:x]))

# without `by` and without `if`

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
using Statistics

d"egen :x = mean(:PetalWidth)"
@test all(.!ismissing.(df.x) )
@test df.x[1] ≈ 1.19933333 atol = 1e-4
select!(df, Not([:x]))
d"egen :x = :SepalLength "
@test all(.!ismissing.(df.x)  )
@test df.x[1] ≈ 5.1 atol = 1e-4
select!(df, Not([:x]))
d"egen :x = 1.0 "
@test all(.!ismissing.(df.x)  )
@test df.x[1] ≈ 1.0 atol = 1e-4
select!(df, Not([:x]))

# ereplace *************

# with `by` and `if`

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
using Statistics

d"gen :x = 1.0"

d"bysort :Species (:SepalLength) : erep :x = mean(:PetalWidth) if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
d"bysort :Species (:SepalLength) : erep :x = :SepalLength if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
d"bysort :Species (:SepalLength) : erep :x = 1.0 if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )

d"bysort :Species (:SepalLength) : erep :x = mean(:PetalWidth) "
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
d"bysort :Species (:SepalLength) : erep :x = :SepalLength"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
d"bysort :Species (:SepalLength) : erep :x = 1.0 "
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )

d"erep :x = mean(:PetalWidth) if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
d"erep :x = :SepalLength if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )
d"erep :x = 1.0 if :SepalWidth .< 3.4"
@test all(.!ismissing.(df.x) .| (df.SepalWidth .>= 3.4) )

d"erep :x = mean(:PetalWidth)"
@test all(.!ismissing.(df.x) )
@test df.x[1] ≈ 1.19933333 atol = 1e-4
d"erep :x = :SepalLength "
@test all(.!ismissing.(df.x)  )
d"erep :x = 1.0 "
@test all(.!ismissing.(df.x)  )
@test df.x[1] ≈ 1.0 atol = 1e-4

# `merge` ************************************************************************

# 1:1
people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
jobs = DataFrame(ID = [20, 40], Job = ["Lawyer", "Doctor"])
Douglass.set_active_df(:people)
d"merge_11 :ID using jobs"
@test size(people) == (2,3)

people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
jobs = DataFrame(ID = [20, 60], Job = ["Lawyer", "Astronaut"])
Douglass.set_active_df(:people)
d"merge_11 :ID using jobs"
@test size(people) == (3,3)

# multiple keys
people = DataFrame(ID = [20, 40], Birthday = ["1980-01-01", "1970-01-01"], Name = ["John Doe", "Jane Doe"])
jobs = DataFrame(ID = [20, 40], Birthday = ["1980-01-01", "1970-01-01"], Job = ["Lawyer", "Doctor"])
Douglass.set_active_df(:people)
d"merge_11 :ID :Birthday using jobs"
@test size(people) == (2,4)

# 1:m
people = DataFrame(ID = [20, 40], Name = ["John Doe", "Jane Doe"])
jobs = DataFrame(ID = [20, 20, 60], Job = ["Lawyer", "Economist", "Astronaut"])
Douglass.set_active_df(:people)
d"merge_1m :ID using jobs"
@test size(people) == (4,3)

# m:1
people = DataFrame(ID = [20, 40, 40], Name = ["John Doe", "Jane Doe", "The CEO"])
jobs = DataFrame(ID = [20, 40, 60], Job = ["Lawyer", "Doctor", "Astronaut"])
Douglass.set_active_df(:people)
d"merge_m1 :ID using jobs"
@test size(people) == (4,3)


# `rename` ***********************************************************************

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"rename :SepalLength :SL"
@test :SL ∈ propertynames(df)

# `replace` **********************************************************************

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"gen :x = 1.0"

# `replace` without anything else 
d"replace :x = 1.0"
@test all(df.x .== 1.0)
d"replace :x = :SepalLength"
@test all(df.x .== df.SepalLength)
d"replace :x = :SepalWidth + :PetalLength"
@test (:x ∈ propertynames(df))
@test df[1,:x] ≈ 4.9 atol = 1e-4
d"replace :x = :SepalWidth + :PetalLength if :PetalLength .> 1.3"
@test all((df.x .== df.SepalWidth .+ df.PetalLength) .| (df.PetalLength .<= 1.3))
d"replace :x = 99 if :PetalLength .> 1.3"
# replace does not change the type
@test (eltype(df.x) == Union{Missing, Float64})
df[!,:x] = ones(Int64,150)
allowmissing!(df, :x)
d"replace :x = _n"
@test (df.x[1] == 1) && (df.x[end] == 150)
# can we use stuff from julia?
d"replace :x = rand(0:10)"
@test (eltype(df.x) == Union{Missing, Int64})

# `replace` with `bysort` 

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
d"gen :x = 1.0"

d"by :Species : replace :x = 1.0"
@test all(df.x .== 1.0)
d"by :Species : replace :x = :SepalLength"
@test all(df.x .== df.SepalLength)
d"by :Species : replace :x = :SepalWidth + :PetalLength"
@test (:x ∈ propertynames(df))
@test df[1,:x] ≈ 4.9 atol = 1e-4
d"bysort :Species (:SepalLength) : replace :x = :SepalWidth + :PetalLength if :PetalLength .> 1.3"
@test sum(skipmissing(df.x)) ≈ 1022.3 atol = 1e-4
d"gen :y = 1"
d"bysort :Species (:SepalLength) : replace :y = 99 if :PetalLength .> 1.3"
@test (eltype(df.y) == Union{Missing, Int64})
d"by :Species : replace :y = _n"
@test (df.y[1] == 1) && (df.y[end] == 50)
# this should keep :y as a Int64
d"bysort :Species (:SepalLength) : replace :y = 99.0 if :SepalLength > 7.8"
@test (eltype(df.y) == Union{Missing, Int64})
d"gen :z = 0.0"
d"bysort :Species (:SepalLength) : replace :z = :x[_n - 2]"
sort!(df, [:Species, :SepalLength])
d"replace :z = 1.0"
@test (:z ∈ propertynames(df))
@test df[1,:z] == 1.0
d"replace :z = :SepalWidth + :PetalLength"
@test sum(skipmissing(df.z)) ≈ 1022.3  atol = 1e-4
select!(df, Not(:z))
d"gen :z = 0.0"
d"replace :z = :SepalWidth + :PetalLength if :PetalWidth > 1.8"
@test sum(skipmissing(df.z)) ≈ 295.9  atol = 1e-4
d"replace :z = _n"

# `reshape` **********************************************************************


df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

# with one variable
df.id = collect(1:(size(df,1)))
select!(df,Not([:PetalLength,:PetalWidth]))
d"reshape_long :Sepal , i(:id) j(:Var)"
@test :Var ∈ propertynames(df)
@test :Sepal ∈ propertynames(df)
@test size(df,1) == 300
d"reshape_wide :Sepal , i(:id) j(:Var)"
@test :SepalLength ∈ propertynames(df)
@test :SepalWidth ∈ propertynames(df)
@test size(df,1) == 150
df2 = dataset("datasets", "iris")
for v in [:SepalLength, :SepalWidth]
    @test all(df[!,v] .== df2[!,v])
end

# with two variables
df = dataset("datasets", "iris")
Douglass.set_active_df(:df)
df.id = collect(1:(size(df,1)))

d"reshape_long :Sepal :Petal, i(:id) j(:Var)"
@test :Var ∈ propertynames(df)
@test :Sepal ∈ propertynames(df)
@test :Petal ∈ propertynames(df)
@test size(df,1) == 300
d"reshape_wide :Sepal :Petal, i(:id) j(:Var)"
@test :SepalLength ∈ propertynames(df)
@test :SepalWidth ∈ propertynames(df)
@test :PetalLength ∈ propertynames(df)
@test :PetalWidth ∈ propertynames(df)
@test size(df,1) == 150
df2 = dataset("datasets", "iris")
for v in [:SepalLength, :SepalWidth, :PetalLength, :PetalWidth]
    @test all(df[!,v] .== df2[!,v])
end

# with two index variables:
wide = DataFrame(x = 1:12,
       a  = 2:13,
       b  = 3:14,
       val1  = randn(12),
       val2  = randn(12),
       cname = repeat(["c", "d"], inner =6)
       )
Douglass.set_active_df(:wide)
d"reshape_wide :val1 :val2, i(:x :a :b) j(:cname)"
@test [:x,:a,:b,:val1c,:val1d,:val2c,:val2d] ⊆ propertynames(wide)
d"reshape_long :val1 :val2, i(:x :a :b) j(:cname)"
@test [:x,:a,:b,:cname,:val1,:val2] ⊆ propertynames(wide)

# `sort` *************************************************************************

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

@test df.SepalLength[1] ≈ 5.1 atol = 1e-4
d"sort :SepalLength"
@test df.SepalLength[1] ≈ 4.3 atol = 1e-4
d"sort :PetalLength :SepalLength"
@test df.SepalLength[1] ≈ 4.6 atol = 1e-4

# `duplicates_drop` *************************************************************************

using Douglass
df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"duplicates_drop :SepalLength :SepalWidth"
@test size(df,1) == size(unique([(df.SepalLength[i],df.SepalWidth[i]) for i=1:size(df,1)]),1)
people = DataFrame(ID = [20, 20, 40], Name = ["John Doe", "John Doe", "Jane Doe"])
Douglass.set_active_df(:people)
d"duplicates_drop"
@test size(people,1) == 2

# Pseudo-String Interpolation *******************

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

name_of_new_var = "myname"
d"gen :$$(name_of_new_var) = 1.0"
@test :myname ∈ propertynames(df)
@test df[1,:myname] == 1.0

# Multiline expressions *******************

df = dataset("datasets", "iris")
Douglass.set_active_df(:df)

d"""
gen :x = 5
gen :y = 6
"""
@test [:x,:y] ⊆ propertynames(df)

# Multiline expressions on a DF *******************

iris = dataset("datasets", "iris")
Douglass.set_active_df(:iris)

active = Douglass.get_active_df()
@test active === :iris

neuro = dataset("boot", "neuro")

Douglass.@douglass neuro """
gen :x = 5.0
gen :y = 6.6
"""
@test [:x,:y] ⊆ propertynames(neuro)

@test active === :iris

# *******************

# cheatsheet
macroexpand(Main, :(@d_str("rename :SepalLength :SomethingBetter")))
macroexpand(Main, :(@d_str("bysort :Species (:SepalLength) : gen :z = 1.0 if :SepalLength .< 1000.0")))


macroexpand(Main, :(Douglass.@d_str("gen :x = 1.0")))
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
