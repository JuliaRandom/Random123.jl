import Base: copy, copyto!, ==
import Random: rand, seed!
import RandomNumbers: gen_seed, split_uint, union_uint, seed_type, unsafe_copyto!, unsafe_compare

"""
```julia
ARS1x{R} <: R123Generator1x{UInt128}
ARS1x([seed, R=7])
```

ARS1x is one kind of ARS Counter-Based RNGs. It generates one `UInt128` number at a time.

`seed` is an `Integer` which will be automatically converted to `UInt128`.

`R` denotes to the Rounds which should be at least 1 and no more than 10. With 7 rounds (by default), it has
a considerable safety margin over the minimum number of rounds with no known statistical flaws, but still has
excellent performance.

Only available when [`R123_USE_AESNI`](@ref).
"""
mutable struct ARS1x{R} <: R123Generator1x{UInt128}
    x::__m128i
    ctr::__m128i
    key::__m128i
end

function ARS1x(seed::Integer = gen_seed(UInt128), R::Integer = 7)
    @assert 1 ≤ R ≤ 10
    r = ARS1x{Int(R)}(zero(__m128i), zero(__m128i), zero(__m128i))
    seed!(r, seed)
end

function seed!(r::ARS1x, seed::Integer=gen_seed(UInt128))
    r.x = zero(__m128i)
    r.ctr = zero(__m128i)
    r.key = seed % UInt128
    random123_r(r)
    r
end

@inline seed_type(::Type{ARS1x{R}}) where R = UInt128

copyto!(dest::ARS1x{R}, src::ARS1x{R}) where R = unsafe_copyto!(dest, src, UInt128, 3)

copy(src::ARS1x{R}) where R = ARS1x{R}(src.x, src.ctr, src.key)

==(r1::ARS1x{R}, r2::ARS1x{R}) where R = unsafe_compare(r1, r2, UInt128, 3)

"""
```julia
ARS4x{R} <: R123Generator4x{UInt32}
ARS4x([seed, R=7])
```

ARS4x is one kind of ARS Counter-Based RNGs. It generates four `UInt32` numbers at a time.

`seed` is a `Tuple` of four `Integer`s which will all be automatically converted to `UInt32`.

`R` denotes to the Rounds which must be at least 1 and no more than 10. With 7 rounds (by default), it has a
considerable safety margin over the minimum number of rounds with no known statistical flaws, but still has
excellent performance.

Only available when [`R123_USE_AESNI`](@ref).
"""
mutable struct ARS4x{R} <: R123Generator4x{UInt32}
    x::__m128i
    ctr1::__m128i
    key::__m128i
    p::Int
end

function ARS4x(seed::NTuple{4, Integer}=gen_seed(UInt32, 4), R::Integer=7)
    @assert 1 ≤ R ≤ 10
    r = ARS4x{Int(R)}(zero(__m128i), zero(__m128i), zero(__m128i), 0)
    seed!(r, seed)
end

function seed!(r::ARS4x, seed::NTuple{4, Integer}=gen_seed(UInt32, 4))
    r.ctr1 = zero(__m128i)
    r.key = union_uint(Tuple(x % UInt32 for x in seed))
    r.p = 0
    r.x = ars1xm128i(r)
    r
end

@inline seed_type(::Type{ARS4x{R}}) where R = NTuple{4, UInt32}

function copyto!(dest::ARS4x{R}, src::ARS4x{R}) where R
    unsafe_copyto!(dest, src, UInt128, 3)
    dest.p = src.p
    dest
end

copy(src::ARS4x{R}) where R = ARS4x{R}(src.x, src.ctr1, src.key, src.p)

==(r1::ARS4x{R}, r2::ARS4x{R}) where R = unsafe_compare(r1, r2, UInt128, 3) && r1.p ≡ r2.p

@generated function ars1xm128i(r::Union{ARS1x{R}, ARS4x{R}}) where R
    @assert R isa Int && 1 ≤ R ≤ 10
    rounds = [quote
        kk += kweyl
        v = _aes_enc(v, kk)
    end for _ in 2:R]
    ctr = :(r.ctr)
    if r <: ARS4x
        ctr.args[2] = :(:ctr1)
    end
    quote
        ctr = $ctr
        key = r.key
        kweyl = __m128i(0xbb67ae8584caa73b, 0x9e3779b97f4a7c15)
        kk = key
        v = ctr ⊻ kk
        q1 = UInt128(ctr)
        q2 = UInt128(key)
        $(rounds...)
        kk += kweyl
        ret = _aes_enc_last(v, kk)
    end
end

@inline function random123_r(r::ARS1x{R}) where R
    r.x = ars1xm128i(r)
    (UInt128(r.x),)
end


@inline function random123_r(r::ARS4x{R}) where R
    r.x = ars1xm128i(r)
    split_uint(UInt128(r.x), UInt32)
end


