import Random: seed!
using Test: @test, @testset

using RandomNumbers
using Random123

import RandomNumbers: split_uint
import Random123: uint64x2

@testset "Accelerated ARS" begin
    x = zero(uint64x2)
    ctr = uint64x2(0x9799b5d54f7b9227, 0xb47607190d0dfefb)
    key = uint64x2(0x07b8e4b6aa98ec24, 0x5a7da274d3b8146a)
    @test rand(ARS1x{1}(x, ctr, key), UInt128) ≡ 0x1a0b14c707b64224e548ef12331396ef
    @test rand(ARS1x{2}(x, ctr, key), UInt128) ≡ 0x3ced8e0970690f718336318ba22e8ae1
    @test rand(ARS1x{3}(x, ctr, key), UInt128) ≡ UInt128(uint64x2(0xb6621a8b006319e8, 0x67c841642c32fc19))
    @test rand(ARS1x{10}(x, ctr, key), UInt128) ≡ UInt128(uint64x2(0xac35df44f996ed82, 0x4e287697bad2f9a2))

    key = rand(UInt128)
    r = ARS1x(key)
    r1 = ARS4x(split_uint(key, UInt32))
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
