# Commands implemented

## `generate`
Creates a new variable and assigns the output from an expression to it.
```
[bysort <varlist> (<varlist>):] generate <expression> [if <expression>]
```
The type of the variable is set to be what the expression evaluates to (and allows `missing`). `generate` operates row-by-row, so you can use `_n` to denote the current row index and do not need to broadcast operators.

## `replace`
Recplaces the content of a variable, but does not change the type.
```
[bysort <varlist> (<varlist>):] replace <expression> [if <expression>]
```
`replace` works like `generate` in that it operates row-by-row.

## `egenerate` (`egen`) and `ereplace` (`erep`)
- Creates a new variable, operates on vectors
```
[bysort <varlist> (<varlist>):] egenerate <var> = <expression> [if <expression>]
```
The key difference between `generate` and `egen` is that the latter operates on vectors, e.g. you can do `by :group: egen :mymean = Statistics.mean(:var)`. That means that operations on scalars need to be broadcast (Julia's `.` syntax), e.g. `egen :mysum = :a .+ :b`.

`egen` tries to determine the new variable's type by evaluating the expression. Types can also be set explicitly, and this is currently faster: `egen :mysum::Float64 = mean(:var)`.

There is also an analogous version `ereplace` (or `erep` for short) that replaces values of existing variables

## `drop`
Drops the specified observations (if used in conjunction with `if`) or variables (without `if`)
```
drop <varlist>
[bysort <varlist> (<varlist>):] drop if <expression>
```
The form with `if` operates row-by-row analogously to `generate`, so use expessions that evaluate to a scalar Boolean variable.

There is also an analogous command, `keep`, that drops all but the specified observations or variables.

## `rename`
Rename a variable
```
rename <var> <var>
```
The first symbol is the old variable name and needs to be an existing column in the active DataFrame, the second symbol is the new name.

## `sort`
Sort the rows of the active `DataFrame` by the specified columns
```
sort <varlist>
```

## `reshape`
Reshape the activate `DataFrame` between wide and long format
```
reshape_wide <varlist> , i(<varlist>) j(<varlist>)
reshape_long <varlist> , i(<varlist>) j(<varlist>)
```
See the [documentation in the Stata manual](https://www.stata.com/manuals13/dreshape.pdf).

## `merge`
Merge the active `DataFrame` with another one in the local scope
```
`merge_11 <varlist> using <DataFrame> , [options]`
`merge_m1 <varlist> using <DataFrame> , [options]`
`merge_1m <varlist> using <DataFrame> , [options]`
```
See the [documentation in the Stata manual](https://www.stata.com/manuals13/dmerge.pdf). The right-hand-side `DataFrame` must be already in the local scope.

## `duplicates_drop`
Delete duplicate rows, keeping only the first occurrence of unique rows. If `<varlist>` is specified, the returned DataFrame contains complete rows, retaining in each case the first instance for which the specified set of variables is unique.
```
duplicates_drop [<varlist>]
```