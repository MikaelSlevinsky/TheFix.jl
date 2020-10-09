using TheFix, Test

import TheFix.cleanse

A = ones(2, 3)
x = 1.0

TheFix.@safeword fix

@testset "Fixed Errors" begin
    @testset "UndefVarError" begin
        @test cleanse(:xx) == :x
        @test cleanse(:(exo(sim(1)))) == :(exp(sin(1)))
        @test cleanse(:(factorrial(factoreal(2)))) == :(factorial(factorial(2)))
    end
    @testset "DomainError" begin
        @test cleanse(:(sqrt(-1.0))) == :(sqrt(Complex(-1.0)))
        @test cleanse(:(2^(1-3))) == :(2 ^ float(1 - 3))
        @test cleanse(:(log2(-2.0))) == :(log2(Complex(-2.0)))
        @test cleanse(:([2 1; 1 0]^(1 - 3))) == :([2 1; 1 0] ^ float(1 - 3))
    end
    @testset "OverflowError" begin
        @test cleanse(:(factorial(21))) == :(factorial(big(21)))
        @test cleanse(:(factorrial(factoreal(4)))) == :(factorial(big(factorial(4))))
        @test cleanse(:(gcd(typemin(Int), typemin(Int)))) == :(gcd(widen(typemin(Int)), widen(typemin(Int))))
        @test cleanse(:(gcd(typemin(Int), Int(0)))) == :(gcd(widen(typemin(Int)), widen(Int(0))))
        s = x -> 1102938470918723 + x*(102394812390847 + x*12349812309487)
        @test cleanse(:($s(1323457//20345))) == :($s(widen(1323457 // 20345)))
    end
    @testset "DivideError" begin
        @test cleanse(:(2 ÷ 0)) == :(2 / 0)
        @test cleanse(:(div(2, 0, RoundUp))) == :(2 / 0)
        @test cleanse(:(5 % 0)) == :(5 - 0 * (5 / 0))
        @test cleanse(:(rem(2, 0, RoundDown))) == :(2 - 0 * round(2 / 0, RoundDown))
        @test cleanse(:(fld(2, 0))) == :(2 / 0)
        @test cleanse(:(divrem(2, 0))) == :((2 / 0, 2 - 0 * (2 / 0)))
    end
    @testset "BoundsError" begin
        @test cleanse(:(A[7])) == :(A[clamp(7, extrema(eachindex(A))...)])
        @test cleanse(:(B[1:7])) == :(A[intersect(1:7, eachindex(A))])
        @test cleanse(:(D[3, 3])) == :(A[clamp(3, extrema(axes(A, 1))...), 3])
        @test cleanse(:(E[3, 4])) == :(A[clamp(3, extrema(axes(A, 1))...), clamp(4, extrema(axes(A, 2))...)])
        @test cleanse(:(F[1:5, 1:5])) == :(A[intersect(1:5, axes(A, 1)), intersect(1:5, axes(A, 2))])
    end
end
