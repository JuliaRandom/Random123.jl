import Base: copy, copyto!, ==
import Random: rand, seed!
import RandomNumbers: gen_seed, split_uint, union_uint, seed_type, unsafe_copyto!, unsafe_compare

"""
```julia
ARS1x{R} <: AbstractAESNI1x
ARS1x([seed, R=7])
```

ARS1x is one kind of ARS Counter-Based RNGs. It generates one `UInt128` number at a time.

`seed` is an `Integer` which will be automatically converted to `UInt128`.

`R` denotes to the Rounds which should be at least 1 and no more than 10. With 7 rounds (by default), it has
a considerable safety margin over the minimum number of rounds with no known statistical flaws, but still has
excellent performance.

Only available when [`R123_USE_AESNI`](@ref).
"""
mutable struct ARS1x{R} <: AbstractAESNI1x
    x::uint64x2
    ctr::uint64x2
    key::uint64x2
end

function ARS1x(seed::Integer=gen_seed(UInt128), R::Integer = 7)
    R = Int(R)
    @assert 1 ≤ R ≤ 10
    m0 = zero(uint64x2)
    r = ARS1x{R}(m0, m0, m0)
    seed!(r, seed)
end

function seed!(r::ARS1x, seed::Integer=gen_seed(UInt128))
    r.x = zero(uint64x2)
    r.ctr = zero(uint64x2)
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
ARS4x{R} <: AbstractAESNI4x
ARS4x([seed, R=7])
```

ARS4x is one kind of ARS Counter-Based RNGs. It generates four `UInt32` numbers at a time.

`seed` is a `Tuple` of four `Integer`s which will all be automatically converted to `UInt32`.

`R` denotes to the Rounds which must be at least 1 and no more than 10. With 7 rounds (by default), it has a
considerable safety margin over the minimum number of rounds with no known statistical flaws, but still has
excellent performance.

Only available when [`R123_USE_AESNI`](@ref).
"""
mutable struct ARS4x{R} <: AbstractAESNI4x
    x::uint64x2
    ctr1::uint64x2
    key::uint64x2
    p::Int
end

function ARS4x(seed::NTuple{4, Integer}=gen_seed(UInt32, 4), R::Integer=7)
    R = Int(R)
    @assert 1 ≤ R ≤ 10
    r = ARS4x{R}(zero(uint64x2), zero(uint64x2), zero(uint64x2), 0)
    seed!(r, seed)
end

function seed!(r::ARS4x, seed::NTuple{4, Integer}=gen_seed(UInt32, 4))
    r.ctr1 = zero(uint64x2)
    r.key = union_uint(Tuple(x % UInt32 for x in seed))
    r.p = 0
    random123_r(r)
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

function expr_ars1xm128i(expr_key, expr_ctr, R)
    @assert R isa Int && 1 ≤ R ≤ 10
    rounds = [quote
        kk += kweyl
        v = _aes_enc(v, kk)
    end for _ in 2:R]
    quote
        ctr = $(expr_ctr)
        key = $(expr_key)
        kweyl = uint64x2(0xbb67ae8584caa73b, 0x9e3779b97f4a7c15)
        kk = key
        v = ctr ⊻ kk
        q1 = UInt128(ctr)
        q2 = UInt128(key)
        $(rounds...)
        kk += kweyl
        ret = _aes_enc_last(v, kk)
    end
end

@generated function ars1xm128i(r::Union{ARS1x{R}, ARS4x{R}}) where R
    expr_ctr = if r <: ARS1x
        :(r.ctr)
    elseif r <: ARS4x
        :(r.ctr1)
    else
        :(error("Unreachable"))
    end
    expr_key = :(r.key)
    expr_ars1xm128i(expr_key, expr_ctr, R)
end

@generated function ars(key::Tuple{uint64x2}, ctr::Tuple{uint64x2}, ::Val{R})::Tuple{uint64x2} where {R}
    :(($(expr_ars1xm128i(:(only(key)), :(only(ctr)), R)),))
end

"""
    ars(key::Tuple{UInt128}, ctr::Tuple{UInt128}, rounds::Val{R})::Tuple{UInt128} where {R}

Functional variant of [`ARS1x`](@ref) and [`ARS4x`](@ref). 
This function if free of mutability and side effects.
"""
function ars(key::Tuple{UInt128}, ctr::Tuple{UInt128}, rounds::Val{R})::Tuple{UInt128} where {R}
    k = map(uint64x2, key)
    c = map(uint64x2, ctr)
    map(UInt128,ars(k,c,rounds))
end

get_key(r::Union{ARS1x, ARS4x}) = (UInt128(r.key),)
get_ctr(r::ARS1x) = (UInt128(r.ctr),)
get_ctr(r::ARS4x) = (UInt128(r.ctr1),)

@inline function random123_r(r::ARS1x{R}) where R
    r.x = ars1xm128i(r)
    (UInt128(r.x),)
end

@inline function random123_r(r::ARS4x{R}) where R
    r.x = ars1xm128i(r)
    split_uint(UInt128(r.x), UInt32)
end


