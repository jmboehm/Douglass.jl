# Frequently Asked Questions

## What is the objective of Douglass.jl?

The objective of Douglass.jl is to allow users that are proficient in Stata to clean and manipulate their data in a Julia environment with relatively little exposure to Julia's data ecosystem. In other words, we want you to be productive with Julia without having to dive deep into DataFrames.jl or DataFramesMeta.jl. 

## I'm a Stata user. Do I need to know Julia to productively use Douglass.jl?

Probably at least a bit, yes. Douglass.jl allows you to write something that looks very much like Stata code, and transforms it into Julia code. In the end, all the operations are executed on Julia variables, so you should know at least a bit about Julia's type system and [`Missing`s](https://docs.julialang.org/en/v1/manual/missing/). 

## What are the advantages of Douglass.jl over DataFrames.jl, DataFramesMeta.jl, and other data manipulation packages?

Douglass.jl exposes a different syntax to the user, compared to these packages. You may or may not like Stata's syntax (people have strong feelings about this!); if you do like Stata's syntax, this package may be for you.

## Why is my code slow when I run it for the first time?

Julia usually compiles each function only when it is being run for the first time. If you code contains a function that is being called for the first time, it will need to incur the compilation time.

## Can I see the code that Douglass.jl produces?

Yes. The Julia function [`macroexpand`](https://docs.julialang.org/en/v1/base/base/#Base.@macroexpand) is useful here. For example:
```julia
macroexpand(Main, :(Douglass.@d_str("gen :x = 1.0")))
```

## What are the design principles of Douglass.jl?

We're trying to have a package that allows someone that knows Stata syntax to be productive in Julia with minimal effort. Hence: (1) we stay as close as possible to Stata's syntax; (2) we generate code that produces output as close as possible to what a Stata user would expect. At the same time, we try to fix obvious inconsistencies and limitations of Stata. The document [Differences from Stata](differences-from-Stata.md) explains some of them. 
