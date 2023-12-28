import Random: seed!
using Test: @test, @testset

using RandomNumbers
using Random123

import RandomNumbers: split_uint
import Random123: __m128i, AESNIKey

@testset "Accelerated AESNI" begin
    x = zero(__m128i)
    ctr = __m128i(0x9799b5d54f7b9227b47607190d0dfefb)
    key = 0x07b8e4b6aa98ec245a7da274d3b8146a
    aesni_key = AESNIKey(key)
    @test rand(AESNI1x(x, ctr, aesni_key), UInt128) ≡ 0x60f4c27fe48fe1b8c5f4568a585b0dc0

    r = AESNI1x(key)
    r1 = AESNI4x(split_uint(key, UInt32))
    @test seed_type(r) ≡ UInt128
    @test seed_type(r1) ≡ NTuple{4, UInt32}
    @test copyto!(copy(r), r) == r
    @test copyto!(copy(r1), r1) == r1
    @test UInt128(r.x) ≡ rand(r1, UInt128)
    @test rand(r, UInt128) ≡ rand(r1, UInt128)
    set_counter!(r, 0)
    set_counter!(r1, 1)
    @test rand(r, Tuple{UInt128})[1] ≡ rand(r1, UInt128)
end
