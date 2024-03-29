using TheFix, Test

import TheFix.cleanse

A = ones(2, 3)
x = 1.0

TheFix.@safeword fix true
TheFix.@safeword FIX false

@testset "Fixed Errors" begin
    @testset "UndefVarError" begin
        @test cleanse(:xx; safe = false) == :x
        @test cleanse(:(exo(sim(1))); safe = false) == :(exp(sin(1)))
        @test cleanse(:(factorrial(factoreal(2))); safe = false) == :(factorial(factorial(2)))
    end
    @testset "DomainError" begin
        @test cleanse(:(sqrt(-1.0))) == :(sqrt(Complex(-1.0)))
        @test cleanse(:(sqrt.((-1.0, 2.0)))) == :(sqrt.(Complex.((-1.0, 2.0))))
        @test cleanse(:(2^(1-3))) == :(2 ^ float(1 - 3))
        @test cleanse(:(2 .^ (-2:2))) == :(2 .^ float.(-2:2))
        @test cleanse(:(2 .^ (-2, -1, 0, 1, 2))) == :(2 .^ float.((-2, -1, 0, 1, 2)))
        @test cleanse(:(log2(-2.0))) == :(log2(Complex(-2.0)))
        @test cleanse(:([2 1; 1 0]^(1 - 3))) == :([2 1; 1 0] ^ float(1 - 3))
        @test cleanse(:(exponent(0.0))) == :(exponent(0.0))
    end
    @testset "OverflowError" begin
        @test cleanse(:(factorial(21))) == :(factorial(big(21)))
        @test cleanse(:(factorrial(factoreal(4))); safe = false) == :(factorial(big(factorial(4))))
        @test cleanse(:(factorial.((21, 22)))) == :(factorial.(big.((21, 22))))
        @test cleanse(:(binomial(67, 30))) == :(binomial(widen(67), widen(30)))
        @test cleanse(:(gcd(typemin(Int), typemin(Int)))) == :(gcd(widen(typemin(Int)), widen(typemin(Int))))
        @test cleanse(:(gcd([typemin(Int), 1]))) == :(gcd(widen.([typemin(Int), 1])))
        @test cleanse(:(gcd.((typemin(Int), 1), (typemin(Int), 2)))) == :(gcd.(widen.((typemin(Int), 1)), widen.((typemin(Int), 2))))
        @test cleanse(:(gcd(typemin(Int), Int(0)))) == :(gcd(widen(typemin(Int)), widen(Int(0))))
        s = x -> 1102938470918723 + x*(102394812390847 + x*12349812309487)
        @test cleanse(:($s(1323457//20345))) == :($s(widen(1323457 // 20345)))
        @test cleanse(:($s.([1323457//20345, 1323458//20345]))) == :($s.(widen.([1323457 // 20345, 1323458 // 20345])))
        @test cleanse(:(-Rational{UInt}(1, 2))) == :(-(Rational{UInt}(1, 2)))
    end
    @testset "DivideError" begin
        @test cleanse(:(2 ÷ 0)) == :(2 / 0)
        @test cleanse(:(div(2, 0, RoundUp))) == :(2 / 0)
        @test cleanse(:(2 % 0)) == :(2 - 0 * (2 / 0))
        @test cleanse(:(mod(2, 0))) == :(2 - 0 * (2 / 0))
        @test cleanse(:(rem(2, 0, RoundDown))) == :(2 - 0 * round(2 / 0, RoundDown))
        @test cleanse(:(fld(2, 0))) == :(2 / 0)
        @test cleanse(:(divrem(2, 0))) == :((2 / 0, 2 - 0 * (2 / 0)))
        @test cleanse(:(divrem(2, 0, RoundNearest))) == :((2 / 0, 2 - 0 * round(2 / 0, RoundNearest)))
    end
    @testset "BoundsError" begin
        @test cleanse(:(A[7])) == :(A[clamp(7, extrema(eachindex(A))...)])
        @test cleanse(:(B[1:7]); safe = false) == :(A[intersect(1:7, eachindex(A))])
        @test cleanse(:(D[3, 3]); safe = false) == :(A[clamp(3, extrema(axes(A, 1))...), 3])
        @test cleanse(:(E[3, 4]); safe = false) == :(A[clamp(3, extrema(axes(A, 1))...), clamp(4, extrema(axes(A, 2))...)])
        @test cleanse(:(F[1:5, 1:5]); safe = false) == :(A[intersect(1:5, axes(A, 1)), intersect(1:5, axes(A, 2))])
    end
    @testset "Code blocks" begin
        @test cleanse(:(for k in 1:2 printline(k) end); safe = false) == :(for k in 1:2 println(k) end)
        @test cleanse(:(for k in 1:2
            printline(k)
        end); safe = false) == :(for k in 1:2
            println(k)
        end)
        @test cleanse(:(begin x = logarithm(4); y = sine(x) end); safe = false) == :(begin x = log(4); y = sin(x) end)
        @test cleanse(:(begin
            i = 1
            while i < 10
                global t = expp1(i)
                printline("t = $t")
                global i += 1
            end
        end); safe = false) == :(begin
            i = 1
            while i < 10
                global t = expm1(i)
                println("t = $t")
                global i += 1
            end
        end)
    end
end
