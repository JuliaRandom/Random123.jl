using RandomNumbers
using Random123
import Random: seed!
using Test: @test, @test_throws, @testset
using Printf: @printf

@testset "functional" begin
    threefry = Random123.threefry
    for T in [UInt32, UInt64]
        key = (T(123), T(456))
        rng = Threefry2x(T, key)
        x1 = rand(rng, T)
        x2 = rand(rng, T)
        x3 = rand(rng, T)
        x4 = rand(rng, T)
        x5 = rand(rng, T)
        y1,y0 = threefry(key, (T(0), T(0)), Val(20))
        y3,y2 = threefry(key, (T(1), T(0)), Val(20))
        y5,y4 = threefry(key, (T(2), T(0)), Val(20))
        @test x1 === y1
        @test x2 === y2
        @test x3 === y3
        @test x4 === y4
        @test x5 === y5
    end
    for T in [UInt32, UInt64]
        key = (T(123), T(456), T(7), T(8))
        rng = Threefry4x(T, key)
        x1 = rand(rng, T)
        x2 = rand(rng, T)
        x3 = rand(rng, T)
        x4 = rand(rng, T)
        x5 = rand(rng, T)
        x6 = rand(rng, T)
        x7 = rand(rng, T)
        x8 = rand(rng, T)
        x9 = rand(rng, T)
        y1,y2,y3,y4 = threefry(key, (T(0), T(0), T(0), T(0)), Val(20))
        y5,y6,y7,y8 = threefry(key, (T(1), T(0), T(0), T(0)), Val(20))
        y9,_,_,_    = threefry(key, (T(2), T(0), T(0), T(0)), Val(20))
        @test x1 === y1
        @test x2 === y2
        @test x3 === y3
        @test x4 === y4
        @test x5 === y5
        @test x6 === y6
        @test x7 === y7
        @test x8 === y8
        @test x9 === y9
    end
end

function compare_dirs(dir1::AbstractString, dir2::AbstractString)
    files1 = readdir(dir1)
    files2 = readdir(dir2)
    @test files1 == files2

    for file in files1
        file1 = joinpath(dir1, file)
        file2 = joinpath(dir2, file)
        lines1 = readlines(file1)
        lines2 = readlines(file2)
        @test lines1 == lines2
    end
end

strip_cr(line::String) = replace(line, r"\r\n$" => "\n")

@info "Testing Random123"
stdout_ = stdout
pwd_ = pwd()
cd(dirname(@__FILE__))
rm("./actual"; force=true, recursive=true)
mkpath("./actual")

for (rng_name, seed_t, stype, seed, args) in (
    (:Threefry2x, NTuple{2, UInt32}, UInt32, (123, 321), (32,)),
    (:Threefry2x, NTuple{2, UInt64}, UInt64, (123, 321), (32,)),
    (:Threefry4x, NTuple{4, UInt32}, UInt32, (123, 321, 456, 654), (72,)),
    (:Threefry4x, NTuple{4, UInt64}, UInt64, (123, 321, 456, 654), (72,)),
    (:Philox2x,   UInt32, UInt32, 123, (16,)),
    (:Philox2x,   UInt64, UInt64, 123, (16,)),
    (:Philox4x,   NTuple{2, UInt32}, UInt32, (123, 321), (16,)),
    (:Philox4x,   NTuple{2, UInt64}, UInt64, (123, 321), (16,))
)
    outfile = open(string(
        "./actual/check-$(string(lowercase("$rng_name"), sizeof(stype)<<3)).out"
    ), "w")
    redirect_stdout(outfile)

    @eval $rng_name($stype)
    x = @eval $rng_name($stype, $seed, $(args...))
    @test seed_type(x) == seed_t
    @test copyto!(copy(x), x) == x

    x.p = 1
    rand(x, UInt64)
    x.p = 1
    rand(x, UInt128)
    @eval rand($x, NTuple{$(string(rng_name)[end-1]-'0'), $stype})

    set_counter!(x, 0)
    for i in 1:100
        @printf "%.9f\n" rand(x)
    end

    close(outfile)
end
redirect_stdout(stdout_)

compare_dirs("expected", "actual")
cd(pwd_)

include("aesni.jl")
include("ars.jl")
