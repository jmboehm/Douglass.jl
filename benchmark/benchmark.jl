
using DataFrames, Random, BenchmarkTools
using Douglass
using CategoricalArrays

rng = MersenneTwister(12345)

# This is similar to Mathieu Gomez's setup for benchmarking FixedEffectModels
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

# all times are from my 2020 MacBook Pro:
# julia> versioninfo()
# Julia Version 1.6.2
# Commit 1b93d53fc4 (2021-07-14 15:36 UTC)
# Platform Info:
#   OS: macOS (x86_64-apple-darwin18.7.0)
#   CPU: Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz
#   WORD_SIZE: 64
#   LIBM: libopenlibm
#   LLVM: libLLVM-11.0.1 (ORCJIT, skylake)
# Environment:
#   JULIA_EDITOR = code
#   JULIA_NUM_THREADS = 
# Stata is StataMP 15.1 (see code)

gen = @benchmark begin
    d"gen :z = :x1 + :x2"
    d"drop :z"
end

egen = @benchmark begin
    d"bysort :id2 (:id1): egen :z = mean(:x1)"
    d"drop :z"
end

egenif = @benchmark begin
    d"bysort :id2 (:id1): egen :z = mean(:x1) if :x1 .> 0.0"
    d"drop :z"
end

using Statistics
egenpair = @benchmark begin
    d"bysort :id2 (:id1): egen :z = cor(:x1,:x2) if :x1 .> 0.0"
    d"drop :z"
end

# RESHAPING:
rng = MersenneTwister(12345)

N = 1_000_000
K = 100
id1 = floor.(div.(collect(1:N),10))
id2 = mod.(collect(1:N),10)
x1 = 5 * cos.(id1) + 5 * sin.(id2) + randn(N)
x2 =  cos.(id1) +  sin.(id2) + randn(N)
y= 3 .* x1 .+ 5 .* x2 .+ cos.(id1) .+ cos.(id2).^2 .+ randn(N)

df = DataFrame(id1 = categorical(id1), id2 = categorical(id2), x1 = x1, x2 = x2, y = y)
allowmissing!(df)

sort!(df, [:id2, :id1])

df_cpy = deepcopy(df)
# warm up
d"reshape_wide :x1 :x2 :y, i(:id1) j(:id2)"
d"reshape_long :x1 :x2 :y, i(:id1) j(:id2)"
# now for real 
df = deepcopy(df_cpy)
reshapewide = @elapsed d"reshape_wide :x1 :x2 :y, i(:id1) j(:id2)"
reshapelong = @elapsed d"reshape_long :x1 :x2 :y, i(:id1) j(:id2)"

df = deepcopy(df_cpy)
d"duplicates_drop :id1 :id2"
df = deepcopy(df_cpy)
duplicatesdrop = @elapsed d"duplicates_drop :id1 :id2"

# plot the results

using DataFrames, CSV, Gadfly
results = CSV.read("benchmark/resultStata.csv", DataFrame)

rename!(results, :result => :stata)

results[!,:julia] = [median(gen).time/1e9, median(egen).time/1e9, median(egenif).time/1e9, median(egenpair).time/1e9, reshapewide, reshapelong, duplicatesdrop]

results[!,:relative] = results.julia ./ results.stata
results[!,:test] = ["gen", "egen/by", "egen/by\n + if", "egen\n + corr", "reshape\nwide", "reshape\nlong", "duplicates\ndrop"]

# p = plot(results, x = "test", y = "relative", Guide.ylabel("Relative Time (Douglass/Stata)"), Guide.xlabel("Command"), Guide.yticks(ticks= [0, 1, 2, 3, 4, 5 ]))
p = plot(results, x = "test", y = "relative",
    Scale.y_log(labels=d-> @sprintf("%2.2g",exp(d))),
    Guide.ylabel("Relative Time (Douglass/Stata)"), Guide.xlabel("Command"),
    Guide.yticks(ticks=log.([0.01, 0.1, 0.5, 1,2,5,10,20])),
    Theme(panel_fill=colorant"white", background_color=colorant"white")
) 

draw(SVG("benchmark/benchmark.svg", 8inch, 5inch), p)
using Cairo, Fontconfig
draw(PNG("benchmark/benchmark.png", 8inch, 5inch), p)


