cap program drop Tic
program define Tic
	syntax, n(integer)
	timer on `n'
end

cap program drop Toc
program define Toc
	syntax, n(integer) 
	timer off `n'
end

clear

local N 1000000
local K 100

set obs `N'

gen id1 = floor(`N'/`K' * runiform())
gen id2 = floor(`K' * runiform())

gen x1 = 5 * cos(id1) + 5*sin(id2) + rnormal()
gen x2 = cos(id1) + sin(id2) + rnormal()

gen y = 3 * x1 + 5*x2 +cos(id1) + cos(id2)^2 + rnormal()

gen t= runiform()
replace x2 = . if t>0.8
drop t

set processors 1

timer clear
local i = 0
/* write and read */
Tic, n(`++i')
gen z = x1 + x2
drop z
Toc, n(`i')

Tic, n(`++i')
bysort id2 (id1): egen z = mean(x1)
drop z
Toc, n(`i')

Tic, n(`++i')
bysort id2 (id1): egen z = mean(x1) if x1 > 0.0
drop z
Toc, n(`i')

Tic, n(`++i')
bysort id2 (id1): egen z = corr(x1 x2) if x1 > 0.0
drop z
Toc, n(`i')

// reshaping
clear
set obs `N'
gen id1 = floor((_n-0.5)/10)
gen id2 = mod(_n, 10)
gen x1 = 5 * cos(id1) + 5*sin(id2) + rnormal()
gen x2 = cos(id1) + sin(id2) + rnormal()
gen y = 3 * x1 + 5*x2 +cos(id1) + cos(id2)^2 + rnormal()

Tic, n(`++i')
reshape wide x1 x2 y, i(id1) j(id2)
Toc, n(`i')

Tic, n(`++i')
reshape long x1 x2 y, i(id1) j(id2)
Toc, n(`i')

Tic, n(`++i')
duplicates drop id1 id2, force
Toc, n(`i')

drop _all
gen result = .
set obs `i'
timer list
forval j = 1/`i'{
	replace result = r(t`j') if _n == `j'
}
outsheet using "resultStata.csv", replace
