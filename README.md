# TheFix.jl

[![Build Status](https://github.com/MikaelSlevinsky/TheFix.jl/workflows/CI/badge.svg)](https://github.com/MikaelSlevinsky/TheFix.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/MikaelSlevinsky/TheFix.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/MikaelSlevinsky/TheFix.jl)

Congratulations! You've found the fix for the most common errors made in the REPL. Add the package, choose a safe word, and you're back in the game.

```julia
pkg> add TheFix

julia> using TheFix; TheFix.@safeword fix true; TheFix.@safeword FIX false

julia> z = logarithm(sine(4))
ERROR: UndefVarError: sine not defined
Stacktrace:
 [1] top-level scope at REPL[2]:1

julia> fix
[ Info: Couldn't find logarithm. Did you mean log?
y
[ Info: Fixing UndefVarError(:logarithm) with log.
[ Info: Couldn't find sine. Did you mean sin?
yes
[ Info: Fixing UndefVarError(:sine) with sin.
[ Info: Fixing DomainError(-0.7568024953079282, "log will only return a complex result if called with a complex argument. Try log(Complex(x)).") with log(Complex(sin(4))).

julia> z = log(Complex(sin(4)))
-0.2786529640671238 + 3.141592653589793im

julia> n = factorrial(factorreal(4))
ERROR: UndefVarError: factorreal not defined
Stacktrace:
 [1] top-level scope at REPL[5]:1

julia> FIX
[ Info: Fixing UndefVarError(:factorrial) with factorial.
[ Info: Fixing UndefVarError(:factorreal) with factorial.
[ Info: Fixing OverflowError("24 is too large to look up in the table; consider using `factorial(big(24))` instead") with factorial(big(factorial(4))).

julia> n = factorial(big(factorial(4)))
620448401733239439360000

julia> divide(n, 0)
ERROR: UndefVarError: divide not defined
Stacktrace:
 [1] top-level scope at REPL[8]:1

julia> fix
[ Info: Couldn't find divide. Did you mean div?
n
[ Info: Did you mean divrem?
no
[ Info: Did you mean digits?
n
[ Info: Did you mean stride?
no
[ Info: Did you mean diff?
n
[ Info: Couldn't find a fix. What did you mean?
fld
[ Info: Fixing UndefVarError(:divide) with fld.
[ Info: Fixing DivideError() with n / 0.

julia> n / 0
Inf

julia> A = -ones(2, 3)
2×3 Array{Float64,2}:
 -1.0  -1.0  -1.0
 -1.0  -1.0  -1.0

julia> B = square_root.(B[-3:5, 2:4])
ERROR: UndefVarError: B not defined
Stacktrace:
 [1] top-level scope at REPL[12]:1

julia> fix
[ Info: Couldn't find square_root. Did you mean sqrt?

[ Info: Fixing UndefVarError(:square_root) with sqrt.
[ Info: Couldn't find B. Did you mean A?

[ Info: Fixing UndefVarError(:B) with A.
[ Info: Fixing BoundsError([-1.0 -1.0 -1.0; -1.0 -1.0 -1.0], (-3:5, 2:4)) with A[intersect(-3:5, axes(A, 1)), intersect(2:4, axes(A, 2))].
[ Info: Fixing DomainError(-1.0, "sqrt will only return a complex result if called with a complex argument. Try sqrt(Complex(x)).") with sqrt.(Complex.(A[intersect(-3:5, axes(A, 1)), intersect(2:4, axes(A, 2))])).

julia> B = sqrt.(Complex.(A[intersect(-3:5, axes(A, 1)), intersect(2:4, axes(A, 2))]))
2×2 Array{Complex{Float64},2}:
 0.0+1.0im  0.0+1.0im
 0.0+1.0im  0.0+1.0im

```

## How it works

The code recursively and deterministically cleanses an expression of the most recent code executed at the REPL, found in `REPL.find_hist_file()`. For `UndefVarError`s, the code sorts all accessible names by Levenshtein distance and replaces any undefined variable with the closest match. Fixing code this way is an ill-posed problem, so this package may have unintended consequences. The fixed prompt colour is orange because to me it's kind of spooky!
