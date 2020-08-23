
using DataFrames, Random, BenchmarkTools
using Douglass

rng = MersenneTwister(12345)

# This is Mathieu Gomez's setup for benchmarking FixedEffectModels
N = 1_000_000
K = 100
id1 = rand(rng,1:div(N, K), N)
id2 = rand(rng, 1:K, N)
x1 = 5 * cos.(id1) + 5 * sin.(id2) + randn(N)
x2 =  cos.(id1) +  sin.(id2) + randn(N)
y= 3 .* x1 .+ 5 .* x2 .+ cos.(id1) .+ cos.(id2).^2 .+ randn(N)

df = DataFrame(id1 = categorical(id1), id2 = categorical(id2), x1 = x1, x2 = x2, y = y)
allowmissing!(df)

df.x2[rand(rng, 1:10,N) .> 8] .= missing
sort!(df, [:id2, :id1])


set_active_df(:df)
@time d"gen :z = :x1 + :x2"
@time d"drop :z"

# all times are from my 2013 MacBook Pro:
# julia> versioninfo()
# Julia Version 1.4.1
# Commit 381693d3df* (2020-04-14 17:20 UTC)
# Platform Info:
#   OS: macOS (x86_64-apple-darwin18.7.0)
#   CPU: Intel(R) Core(TM) i5-4258U CPU @ 2.40GHz
#   WORD_SIZE: 64
#   LIBM: libopenlibm
#   LLVM: libLLVM-8.0.1 (ORCJIT, haswell)
#
# Stata is StataMP 13.1

# 0.216s
@btime begin
    d"gen :z = :x1 + :x2"
    d"drop :z"
end
# Stata: 0.03s

# 0.185s
@btime begin
    d"bysort :id2 (:id1): egen :z = mean(:x1)"
    d"drop :z"
end
# Stata: 0.35s

# 0.920s
@btime begin
    d"bysort :id2 (:id1): egen :z = mean(:x1) if :x1 .> 0.0"
    d"drop :z"
end
# Stata: 1.44s

using Statistics
# 0.926s
@btime begin
    d"bysort :id2 (:id1): egen :z = cor(:x1,:x2) if :x1 .> 0.0"
    d"drop :z"
end
# Stata: 5.897s

# RESHAPING:


rng = MersenneTwister(12345)

N = 1_000_000
K = 100
id1 = vec(repeat(collect(1:100_000),1,10)' )
id2 = vec(repeat(collect(1:10),100_000,1))
x1 = 5 * cos.(id1) + 5 * sin.(id2) + randn(N)
x2 =  cos.(id1) +  sin.(id2) + randn(N)
y= 3 .* x1 .+ 5 .* x2 .+ cos.(id1) .+ cos.(id2).^2 .+ randn(N)

df = DataFrame(id1 = categorical(id1), id2 = categorical(id2), x1 = x1, x2 = x2, y = y)
allowmissing!(df)

sort!(df, [:id2, :id1])


d"reshape_wide :x1 :x2 :y, i(:id1) j(:id2)"
d"reshape_long :x1 :x2 :y, i(:id1) j(:id2)"


Douglass.@duplicates_assert(df, [:id1, :id2])

include("src/Douglass.jl")
