using Base: llvmcall
import Base.(+)

using ..Random123: R123Generator1x, R123Generator4x
import ..Random123: random123_r, set_counter!

const LLVM_ARCH_STRING::String = @static if R123_USE_ARM_AARCH64_FEAT_AES
    "aarch64"
elseif R123_USE_ARM_AARCH32_FEAT_AES
    "arm"
else
    @error "Impossible situation!  Something has gone seriously wrong."
end

const LITTLE_ENDIAN::Bool = ENDIAN_BOM ≡ 0x04030201

abstract type ArmVec128 end
@inline Base.convert(::Type{T}, x::ArmVec128) where {T<:Union{ArmVec128, UInt128}} =
    unsafe_load(Ptr{T}(pointer_from_objref(Ref(x))))
@inline Base.convert(::Type{T}, x::UInt128) where {T<:ArmVec128} =
    unsafe_load(Ptr{T}(pointer_from_objref(Ref(x))))
@inline Base.UInt128(x::ArmVec128) = convert(UInt128, x)
@inline (::Type{T})(x::Union{ArmVec128, UInt128}) where {T<:ArmVec128} = convert(T, x)
@inline Base.convert(::Type{T}, x::Union{Signed, Unsigned}) where {T<:ArmVec128} =
    convert(T, UInt128(x))
@inline Base.convert(::Type{T}, x::ArmVec128) where T <: Union{Signed, Unsigned} =
    convert(T, UInt128(x))

const VEC_FLAVORS = [(2^(7 - i) => 2^i) for i in 3:6]
for (num_elems, elem_bits) in VEC_FLAVORS
    vec_symb = Symbol("uint$(elem_bits)x$(num_elems)")
    lvec_symb = Symbol("uint$(elem_bits)x$(num_elems)_lvec")
    elem_ty_symb = Symbol("UInt$elem_bits")
    llvm_xor =
        """%3 = xor <$(num_elems) x i$(elem_bits)> %1, %0
        ret <$(num_elems) x i$(elem_bits)> %3"""
    @eval begin
        const $lvec_symb = NTuple{$num_elems, VecElement{$elem_ty_symb}}
        struct $vec_symb <: ArmVec128
            data::$lvec_symb
        end
        @inline $vec_symb(x::Union{UInt128, ArmVec128}) = convert($vec_symb, x)

        @inline function $vec_symb(bytes::Vararg{$elem_ty_symb, $num_elems})
            bytes_prepped = bytes
            @static if $LITTLE_ENDIAN
                bytes_prepped = reverse(bytes_prepped)
            end
            bytes_vec::$lvec_symb = VecElement.(bytes_prepped)
            return $vec_symb(bytes_vec)
        end

        @inline Base.zero(::Type{$vec_symb}) = convert($vec_symb, zero(UInt128))
        @inline Base.xor(a::$vec_symb, b::$vec_symb) = llvmcall(
            $llvm_xor,
            $lvec_symb, Tuple{$lvec_symb, $lvec_symb},
            a.data, b.data,
        ) |> $vec_symb
    end
end

@inline Base.one(::Type{uint64x2}) = uint64x2(zero(UInt64), one(UInt64))
@inline (+)(a::uint64x2, b::uint64x2) = llvmcall(
    """%3 = add <2 x i64> %1, %0
    ret <2 x i64> %3""",
    uint64x2_lvec, Tuple{uint64x2_lvec, uint64x2_lvec},
    a.data, b.data,
) |> uint64x2
@inline (+)(a::uint64x2, b::Integer) = a + uint64x2(UInt128(b))

# Raw NEON instrinsics, provided by FEAT_AES
const ARM_AESE_LLVM_INTRINSIC = "llvm.$LLVM_ARCH_STRING.crypto.aese"
@inline _vaese(a::uint8x16, b::uint8x16) = ccall(
    ARM_AESE_LLVM_INTRINSIC,
    llvmcall,
    uint8x16_lvec,
    (uint8x16_lvec, uint8x16_lvec),
    a.data, b.data,
) |> uint8x16
const ARM_AESMC_LLVM_INTRINSIC = "llvm.$LLVM_ARCH_STRING.crypto.aesmc"
@inline _vaesmc(a::uint8x16) = ccall(
    ARM_AESMC_LLVM_INTRINSIC,
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
