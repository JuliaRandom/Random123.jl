using Base: llvmcall
import Base.(+)

using ..Random123: R123Generator1x, R123Generator4x
import ..Random123: random123_r, set_counter!

const LITTLE_ENDIAN::Bool = ENDIAN_BOM ≡ 0x04030201

const uint64x2_lvec = NTuple{2, VecElement{UInt64}}
struct uint64x2
    data::uint64x2_lvec
end
@inline Base.convert(::Type{uint64x2}, x::UInt128) = unsafe_load(Ptr{uint64x2}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{UInt128}, x::uint64x2) = unsafe_load(Ptr{UInt128}(pointer_from_objref(Ref(x))))
@inline UInt128(x::uint64x2) = convert(UInt128, x)
@inline uint64x2(x::UInt128) = convert(uint64x2, x)
@inline Base.convert(::Type{uint64x2}, x::Union{Signed, Unsigned}) = convert(uint64x2, UInt128(x))
@inline Base.convert(::Type{T}, x::uint64x2) where T <: Union{Signed, Unsigned} = convert(T, UInt128(x))

@inline uint64x2(hi::UInt64, lo::UInt64) = @static if LITTLE_ENDIAN
    uint64x2((VecElement(lo), VecElement(hi)))
else
    uint64x2((VecElement(hi), VecElement(lo)))
end

@inline Base.zero(::Type{uint64x2}) = convert(uint64x2, zero(UInt128))
@inline Base.one(::Type{uint64x2}) = uint64x2(zero(UInt64), one(UInt64))
@inline Base.xor(a::uint64x2, b::uint64x2) = llvmcall(
    """%3 = xor <2 x i64> %1, %0
    ret <2 x i64> %3""",
    uint64x2_lvec, Tuple{uint64x2_lvec, uint64x2_lvec},
    a.data, b.data,
) |> uint64x2
@inline (+)(a::uint64x2, b::uint64x2) = llvmcall(
    """%3 = add <2 x i64> %1, %0
    ret <2 x i64> %3""",
    uint64x2_lvec, Tuple{uint64x2_lvec, uint64x2_lvec},
    a.data, b.data,
) |> uint64x2
@inline (+)(a::uint64x2, b::Integer) = a + uint64x2(UInt128(b))

const uint8x16_lvec = NTuple{16, VecElement{UInt8}}
struct uint8x16
    data::uint8x16_lvec
end
@inline Base.convert(::Type{uint64x2}, x::uint8x16) = unsafe_load(Ptr{uint64x2}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{uint8x16}, x::uint64x2) = unsafe_load(Ptr{uint8x16}(pointer_from_objref(Ref(x))))
@inline uint8x16(x::uint64x2) = convert(uint8x16, x)
@inline uint64x2(x::uint8x16) = convert(uint64x2, x)
@inline Base.convert(::Type{uint8x16}, x::UInt128) = unsafe_load(Ptr{uint8x16}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{UInt128}, x::uint8x16) = unsafe_load(Ptr{UInt128}(pointer_from_objref(Ref(x))))
@inline UInt128(x::uint8x16) = convert(UInt128, x)
@inline uint8x16(x::UInt128) = convert(uint8x16, x)
@inline Base.convert(::Type{uint8x16}, x::Union{Signed, Unsigned}) = convert(uint8x16, UInt128(x))
@inline Base.convert(::Type{T}, x::uint8x16) where T <: Union{Signed, Unsigned} = convert(T, UInt128(x))

@inline function uint8x16(bytes::Vararg{UInt8, 16})
    bytes_prepped = bytes
    @static if LITTLE_ENDIAN
        bytes_prepped = reverse(bytes_prepped)
    end
    bytes_vec::uint8x16_lvec = VecElement.(bytes_prepped)
    return uint8x16(bytes_vec)
end

@inline Base.zero(::Type{uint8x16}) = convert(uint8x16, zero(UInt128))
@inline Base.xor(a::uint8x16, b::uint8x16) = llvmcall(
    """%3 = xor <16 x i8> %1, %0
    ret <16 x i8> %3""",
    uint8x16_lvec, Tuple{uint8x16_lvec, uint8x16_lvec},
    a.data, b.data,
) |> uint8x16

const uint32x4_lvec = NTuple{4, VecElement{UInt32}}
struct uint32x4
    data::uint32x4_lvec
end
@inline Base.convert(::Type{uint64x2}, x::uint32x4) = unsafe_load(Ptr{uint64x2}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{uint32x4}, x::uint64x2) = unsafe_load(Ptr{uint32x4}(pointer_from_objref(Ref(x))))
@inline uint32x4(x::uint64x2) = convert(uint32x4, x)
@inline uint64x2(x::uint32x4) = convert(uint64x2, x)
@inline Base.convert(::Type{uint8x16}, x::uint32x4) = unsafe_load(Ptr{uint8x16}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{uint32x4}, x::uint8x16) = unsafe_load(Ptr{uint32x4}(pointer_from_objref(Ref(x))))
@inline uint32x4(x::uint8x16) = convert(uint32x4, x)
@inline uint8x16(x::uint32x4) = convert(uint8x16, x)
@inline Base.convert(::Type{uint32x4}, x::UInt128) = unsafe_load(Ptr{uint32x4}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{UInt128}, x::uint32x4) = unsafe_load(Ptr{UInt128}(pointer_from_objref(Ref(x))))
@inline UInt128(x::uint32x4) = convert(UInt128, x)
@inline uint32x4(x::UInt128) = convert(uint32x4, x)
@inline Base.convert(::Type{uint32x4}, x::Union{Signed, Unsigned}) = convert(uint32x4, UInt128(x))
@inline Base.convert(::Type{T}, x::uint32x4) where T <: Union{Signed, Unsigned} = convert(T, UInt128(x))

@inline function uint32x4(bytes::Vararg{UInt32, 4})
    bytes_prepped = bytes
    @static if LITTLE_ENDIAN
        bytes_prepped = reverse(bytes_prepped)
    end
    bytes_vec::uint32x4_lvec = VecElement.(bytes_prepped)
    return uint32x4(bytes_vec)
end

@inline Base.zero(::Type{uint32x4}) = convert(uint32x4, zero(UInt128))
@inline Base.xor(a::uint32x4, b::uint32x4) = llvmcall(
    """%3 = xor <4 x i32> %1, %0
    ret <4 x i32> %3""",
    uint32x4_lvec, Tuple{uint32x4_lvec, uint32x4_lvec},
    a.data, b.data,
) |> uint32x4

# Raw NEON instrinsics, provided by FEAT_AES
@inline _vaese(a::uint8x16, b::uint8x16) = ccall(
    "llvm.aarch64.crypto.aese",
    llvmcall,
    uint8x16_lvec,
    (uint8x16_lvec, uint8x16_lvec),
    a.data, b.data,
) |> uint8x16
@inline _vaesmc(a::uint8x16) = ccall(
    "llvm.aarch64.crypto.aesmc",
    llvmcall,
    uint8x16_lvec,
    (uint8x16_lvec,),
    a.data,
) |> uint8x16

"""
Assistant function for AES keygen. Originally compiled for AArch64 from the C source code:
```cpp
uint8x16_t _mm_aeskeygenassist_helper(uint8x16_t a)
{
    uint8x16_t dest = {
        // Undo ShiftRows step from AESE and extract X1 and X3
        a[0x4], a[0x1], a[0xE], a[0xB],  // SubBytes(X1)
        a[0x1], a[0xE], a[0xB], a[0x4],  // ROT(SubBytes(X1))
        a[0xC], a[0x9], a[0x6], a[0x3],  // SubBytes(X3)
        a[0x9], a[0x6], a[0x3], a[0xC],  // ROT(SubBytes(X3))
    };
    return dest;
}
```
Then made architecture-agnostic as LLVM IR.
"""
@inline _aes_key_gen_shuffle_helper(a::uint8x16) = llvmcall(
    """%2 = shufflevector <16 x i8> %0, <16 x i8> undef, <16 x i32> <i32 4, i32 1, i32 14, i32 11, i32 1, i32 14, i32 11, i32 4, i32 12, i32 9, i32 6, i32 3, i32 9, i32 6, i32 3, i32 12>
    ret <16 x i8> %2""",
    uint8x16_lvec, Tuple{uint8x16_lvec},
    a.data,
) |> uint8x16

# Mimics of the x86 AES-NI instrinsics
#
# Algorithm translations courtesy of the SIMD Everywhere and SSE2NEON projects:
# https://github.com/simd-everywhere/simde/blob/v0.8.0-rc1/simde/x86/aes.h
# https://github.com/DLTcollab/sse2neon/blob/v1.6.0/sse2neon.h
@inline function _aes_enc(a::uint64x2, round_key::uint64x2)
    res = _vaesmc(_vaese(uint8x16(a), zero(uint8x16)))
    return uint64x2(res) ⊻ round_key
end
@inline function _aes_enc_last(a::uint64x2, round_key::uint64x2)
    res = _vaese(uint8x16(a), zero(uint8x16))
    return uint64x2(res) ⊻ round_key
end
@inline function _aes_key_gen_assist(a::uint64x2, ::Val{R}) where {R}
    res = _aes_key_gen_shuffle_helper(_vaese(uint8x16(a), zero(uint8x16)))
    r = R % UInt32
    z = zero(UInt32)
    return uint64x2(res) ⊻ uint64x2(uint32x4(r, z, r, z))
end

"""
    _aes_enc_full(a::uint64x2, round_keys::NTuple{N,uint64x2})::uint64x2 where {N}

Full AES encryption flow for N rounds.
"""
@inline function _aes_enc_full(a::uint64x2, round_keys::NTuple{N,uint64x2})::uint64x2 where {N}
    res = uint8x16(a)
    for (i, key) in enumerate(round_keys)
        if i ≢ N
            res = _vaese(res, uint8x16(key))
            if i ≢ N - 1
                res = _vaesmc(res)
            end
        else
            return uint64x2(res ⊻ uint8x16(key))
        end
    end
    return a # pathological 0-round case
end

"Abstract RNG that generates one number at a time and is based on AESNI."
abstract type AbstractAESNI1x <: R123Generator1x{UInt128} end
"Abstract RNG that generates four numbers at a time and is based on AESNI."
abstract type AbstractAESNI4x <: R123Generator4x{UInt32} end

@inline function set_counter!(
    r::AbstractAESNI4x,
    ctr::NTuple{4, Integer}
)
    r.p = 0
    r.ctr1 = union_uint(Tuple(x % UInt32 for x in ctr))
    random123_r(r)
    r
end

@inline inc_counter!(r::AbstractAESNI4x) = (r.ctr1 += one(uint64x2); r)
