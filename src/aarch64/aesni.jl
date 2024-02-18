import Base: copy, copyto!, ==, llvmcall
import Random: rand, seed!
import RandomNumbers: gen_seed, union_uint, seed_type, unsafe_copyto!, unsafe_compare


"The key for AESNI."
mutable struct AESNIKey
    key1::uint64x2
    key2::uint64x2
    key3::uint64x2
    key4::uint64x2
    key5::uint64x2
    key6::uint64x2
    key7::uint64x2
    key8::uint64x2
    key9::uint64x2
    key10::uint64x2
    key11::uint64x2
    AESNIKey() = new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
end

copyto!(dest::AESNIKey, src::AESNIKey) = unsafe_copyto!(dest, src, UInt128, 11)

copy(src::AESNIKey) = copyto!(AESNIKey(), src)

==(key1::AESNIKey, key2::AESNIKey) = unsafe_compare(key1, key2, UInt128, 11)

"""
Assistant function for AES128. Originally compiled for x86 from the C++ source code:
```cpp
R123_STATIC_INLINE __m128i AES_128_ASSIST (__m128i temp1, __m128i temp2) {
    __m128i temp3;
    temp2 = _mm_shuffle_epi32 (temp2 ,0xff);
    temp3 = _mm_slli_si128 (temp1, 0x4);
    temp1 = _mm_xor_si128 (temp1, temp3);
    temp3 = _mm_slli_si128 (temp3, 0x4);
    temp1 = _mm_xor_si128 (temp1, temp3);
    temp3 = _mm_slli_si128 (temp3, 0x4);
    temp1 = _mm_xor_si128 (temp1, temp3);
    temp1 = _mm_xor_si128 (temp1, temp2);
    return temp1;
}
```
Then made architecture-agnostic as LLVM IR.
"""
_aes_128_assist(a::uint64x2, b::uint64x2) = llvmcall(
    """%3 = bitcast <2 x i64> %1 to <4 x i32>
    %4 = shufflevector <4 x i32> %3, <4 x i32> undef, <4 x i32> <i32 3, i32 3, i32 3, i32 3>
    %5 = bitcast <4 x i32> %4 to <2 x i64>
    %6 = bitcast <2 x i64> %0 to <16 x i8>
    %7 = shufflevector <16 x i8> <i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 0, i8 0, i8 0, i8 0>, <16 x i8> %6, <16 x i32> <i32 12, i32 13, i32 14, i32 15, i32 16, i32 17, i32 18, i32 19, i32 20, i32 21, i32 22, i32 23, i32 24, i32 25, i32 26, i32 27>
    %8 = bitcast <16 x i8> %7 to <2 x i64>
    %9 = xor <2 x i64> %8, %0
    %10 = shufflevector <16 x i8> <i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 0, i8 0, i8 0, i8 0>, <16 x i8> %7, <16 x i32> <i32 12, i32 13, i32 14, i32 15, i32 16, i32 17, i32 18, i32 19, i32 20, i32 21, i32 22, i32 23, i32 24, i32 25, i32 26, i32 27>
    %11 = bitcast <16 x i8> %10 to <2 x i64>
    %12 = xor <2 x i64> %9, %11
    %13 = shufflevector <16 x i8> <i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 undef, i8 0, i8 0, i8 0, i8 0>, <16 x i8> %10, <16 x i32> <i32 12, i32 13, i32 14, i32 15, i32 16, i32 17, i32 18, i32 19, i32 20, i32 21, i32 22, i32 23, i32 24, i32 25, i32 26, i32 27>
    %14 = bitcast <16 x i8> %13 to <2 x i64>
    %15 = xor <2 x i64> %12, %5
    %16 = xor <2 x i64> %15, %14
    ret <2 x i64> %16""",
    uint64x2_lvec, Tuple{uint64x2_lvec, uint64x2_lvec},
    a.data, b.data
) |> uint64x2

function _aesni_expand!(k::AESNIKey, rkey::uint64x2)
    k.key1 = rkey
    tmp = _aes_key_gen_assist(rkey, Val(0x1))
    rkey = _aes_128_assist(rkey, tmp)
    k.key2 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x2))
    rkey = _aes_128_assist(rkey, tmp)
    k.key3 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x4))
    rkey = _aes_128_assist(rkey, tmp)
    k.key4 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x8))
    rkey = _aes_128_assist(rkey, tmp)
    k.key5 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x10))
    rkey = _aes_128_assist(rkey, tmp)
    k.key6 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x20))
    rkey = _aes_128_assist(rkey, tmp)
    k.key7 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x40))
    rkey = _aes_128_assist(rkey, tmp)
    k.key8 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x80))
    rkey = _aes_128_assist(rkey, tmp)
    k.key9 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x1b))
    rkey = _aes_128_assist(rkey, tmp)
    k.key10 = rkey

    tmp = _aes_key_gen_assist(rkey, Val(0x36))
    rkey = _aes_128_assist(rkey, tmp)
    k.key11 = rkey

    k
end

AESNIKey(key::UInt128) = _aesni_expand!(AESNIKey(), uint64x2(key))

"""
```julia
AESNI1x <: AbstractAESNI1x
AESNI1x([seed])
```

AESNI1x is one kind of AESNI Counter-Based RNGs. It generates one `UInt128` number at a time.

`seed` is an `Integer` which will be automatically converted to `UInt128`.

Only available when [`R123_USE_AESNI`](@ref).
"""
mutable struct AESNI1x <: AbstractAESNI1x
    x::uint64x2
    ctr::uint64x2
    key::AESNIKey
end

function AESNI1x(seed::Integer=gen_seed(UInt128))
    r = AESNI1x(0, 0, AESNIKey())
    seed!(r, seed)
    r
end

function seed!(r::AESNI1x, seed::Integer=gen_seed(UInt128))
    r.x = zero(uint64x2)
    r.ctr = zero(uint64x2)
    _aesni_expand!(r.key, uint64x2(seed % UInt128))
    random123_r(r)
    r
end

seed_type(::Type{AESNI1x}) = UInt128

function copyto!(dest::AESNI1x, src::AESNI1x)
    dest.x = src.x
    dest.ctr = src.ctr
    copyto!(dest.key, src.key)
    dest
end

copy(src::AESNI1x) = copyto!(AESNI1x(), src)

==(r1::AESNI1x, r2::AESNI1x) = r1.x == r2.x && r1.key == r2.key && r1.ctr == r2.ctr

"""
```julia
AESNI4x <: AbstractAESNI4x
AESNI4x([seed])
```

AESNI4x is one kind of AESNI Counter-Based RNGs. It generates four `UInt32` numbers at a time.

`seed` is a `Tuple` of four `Integer`s which will all be automatically converted to `UInt32`.

Only available when [`R123_USE_AESNI`](@ref).
"""
mutable struct AESNI4x <: AbstractAESNI4x
    x::uint64x2
    ctr1::uint64x2
    key::AESNIKey
    p::Int
end

function AESNI4x(seed::NTuple{4, Integer}=gen_seed(UInt32, 4))
    r = AESNI4x(zero(uint64x2), zero(uint64x2), AESNIKey(), 0)
    seed!(r, seed)
    r
end

function seed!(r::AESNI4x, seed::NTuple{4, Integer}=gen_seed(UInt32, 4))
    key = union_uint(Tuple(x % UInt32 for x in seed))
    r.ctr1 = 0
    _aesni_expand!(r.key, uint64x2(key))
    r.p = 0
    random123_r(r)
    r
end

seed_type(::Type{AESNI4x}) = NTuple{4, UInt32}

function copyto!(dest::AESNI4x, src::AESNI4x)
    unsafe_copyto!(dest, src, UInt128, 2)
    copyto!(dest.key, src.key)
    dest.p = src.p
    dest
end

copy(src::AESNI4x) = copyto!(AESNI4x(), src)
==(r1::AESNI4x, r2::AESNI4x) = unsafe_compare(r1, r2, UInt128, 2) &&
    r1.key == r2.key && r1.p == r2.p

function get_key_uint64x2(o::Union{AESNI1x, AESNI4x})::NTuple{11, uint64x2}
    k = o.key
    (k.key1,k.key2,k.key3,k.key4,k.key5,k.key6,k.key7,k.key8,k.key9,k.key10,k.key11)
end
get_ctr_uint64x2(o::AESNI4x)::Tuple{uint64x2} = (o.ctr1,)
get_ctr_uint64x2(o::AESNI1x)::Tuple{uint64x2} = (o.ctr,)
get_key(o::Union{AESNI1x, AESNI4x})::NTuple{11,UInt128} = map(UInt128, get_key_uint64x2(o))
get_ctr(o::Union{AESNI1x, AESNI4x})::Tuple{UInt128} = map(UInt128, get_ctr_uint64x2(o))

@inline aesni(key::NTuple{11,uint64x2}, ctr::Tuple{uint64x2})::Tuple{uint64x2} =
    (_aes_enc_full(only(ctr), key),)

"""
    aesni(key::NTuple{11,UInt128}, ctr::Tuple{UInt128})::Tuple{UInt128}

Functional variant of [`AESNI1x`](@ref) and [`AESNI4x`](@ref).
This function if free of mutability and side effects.
"""
@inline function aesni(key::NTuple{11,UInt128}, ctr::Tuple{UInt128})::Tuple{UInt128}
    k = map(uint64x2, key)
    c = map(uint64x2, ctr)
    map(UInt128,aesni(k,c))
end


@inline function random123_r(r::AESNI1x)
    r.x = only(aesni(get_key_uint64x2(r), get_ctr_uint64x2(r)))
    (UInt128(r.x),)
end

@inline function random123_r(r::AESNI4x)
    r.x = only(aesni(get_key_uint64x2(r), get_ctr_uint64x2(r)))
    split_uint(UInt128(r.x), UInt32)
end
