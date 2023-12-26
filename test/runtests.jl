using RandomNumbers
using Random123
import Random: seed!
using Test: @test, @test_throws, @testset, @inferred
using Printf: @printf

@info "Testing Random123"

@testset "functional API" begin
    get_key = Random123.get_key
    get_ctr = Random123.get_ctr
    seed1 = 1
    seed2 = (1,2)
    seed4 = (1,2,3,4)
    AlgChoice = Tuple{Random123.AbstractR123, Function, Union{Tuple{}, Tuple{Val}}}
    alg_choices = AlgChoice[
        (Threefry2x(UInt32, seed2) , threefry, (Val(20),)) ,
        (Threefry2x(UInt64, seed2) , threefry, (Val(20),)) ,
        (Threefry4x(UInt32, seed4) , threefry, (Val(20),)) ,
        (Threefry4x(UInt64, seed4) , threefry, (Val(20),)) ,
        (Philox2x(UInt32  , seed1) , philox  , (Val(10),)) ,
        (Philox2x(UInt64  , seed1) , philox  , (Val(10),)) ,
        (Philox4x(UInt32  , seed2) , philox  , (Val(10),)) ,
        (Philox4x(UInt64  , seed2) , philox  , (Val(10),)) ,
    ]
    @static if R123_USE_AESNI
        append!(alg_choices, AlgChoice[
            (AESNI1x(seed1) , aesni , ()        ) ,
            (AESNI4x(seed4) , aesni , ()        ) ,
            (ARS1x(seed1)   , ars   , (Val(7),) ) ,
            (ARS4x(seed4)   , ars   , (Val(7),) ) ,
        ])
    end
    for (rng, alg, options) in alg_choices
        key = @inferred get_key(rng)
        ctr = @inferred get_ctr(rng)
        @test isbitstype(typeof(key))
        @test isbitstype(typeof(ctr))
        @test key isa Tuple
        @test ctr isa Tuple
        @test eltype(key) <: Union{UInt32, UInt64, UInt128}
        @test eltype(ctr) <: Union{UInt32, UInt64, UInt128}
        val1 = @inferred alg(key, ctr, options...)
        val2 = @inferred alg(key, ctr, options...)
        @test val1 === val2
        @test val1 isa Tuple
        @test isbitstype(typeof(val1))
        @test eltype(val1) <: Union{UInt32, UInt64, UInt128}
    end
end
@testset "functional consistency" begin
    get_key = Random123.get_key
    get_ctr = Random123.get_ctr
    for T in [UInt32, UInt64]
        for (rng, alg, option) in [
                (Threefry2x(T, (T(123), T(456))), threefry, Val(20)),
                (Philox2x(T, 456), philox, Val(10)),
           ]

            key = @inferred get_key(rng)
            x1 = rand(rng, T)
            y1,y0 = alg(key, get_ctr(rng), option)
            @test x1 === y1
            x2 = rand(rng, T)
            x3 = rand(rng, T)
            ctr = get_ctr(rng)
            y3,y2 = alg(key, get_ctr(rng), option)
            @test x2 === y2
            @test x3 === y3
        end
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

    if R123_USE_AESNI
        rng = ARS1x(1)
        @test (rand(rng, UInt128),) === ars(get_key(rng), get_ctr(rng), Val(7))
        @test (rand(rng, UInt128),) === ars(get_key(rng), get_ctr(rng), Val(7))
        @test (rand(rng, UInt128),) === ars(get_key(rng), get_ctr(rng), Val(7))
        @test (rand(rng, UInt128),) === ars(get_key(rng), get_ctr(rng), Val(7))

        rng = AESNI1x(1)
        @test (rand(rng, UInt128),) === aesni(get_key(rng), get_ctr(rng))
        @test (rand(rng, UInt128),) === aesni(get_key(rng), get_ctr(rng))
        @test (rand(rng, UInt128),) === aesni(get_key(rng), get_ctr(rng))
        @test (rand(rng, UInt128),) === aesni(get_key(rng), get_ctr(rng))
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

@static if Random123.R123_USE_X86_AES_NI
    include("./x86/aesni.jl")
    include("./x86/ars.jl")
elseif Random123.R123_USE_AARCH64_FEAT_AES
    include("./aarch64/aesni.jl")
    include("./aarch64/ars.jl")
end
