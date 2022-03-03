using Base: llvmcall
import Base.(+)

using ..Random123: R123Generator1x, R123Generator4x
import ..Random123: random123_r, set_counter!

const __m128i = NTuple{2, VecElement{UInt64}}
Base.convert(::Type{__m128i}, x::UInt128) = unsafe_load(Ptr{__m128i}(pointer_from_objref(Ref(x))))
Base.convert(::Type{UInt128}, x::__m128i) = unsafe_load(Ptr{UInt128}(pointer_from_objref(Ref(x))))
UInt128(x::__m128i) = convert(UInt128, x)
__m128i(x::UInt128) = convert(__m128i, x)
Base.convert(::Type{__m128i}, x::Union{Signed, Unsigned}) = convert(__m128i, UInt128(x))
Base.convert(::Type{T}, x::__m128i) where T <: Union{Signed, Unsigned} = convert(T, UInt128(x))

const LITTLE_ENDIAN = ENDIAN_BOM ≡ 0x04030201
__m128i(hi::UInt64, lo::UInt64) = LITTLE_ENDIAN ? (VecElement(lo), VecElement(hi)) : (VecElement(hi), VecElement(lo))

Base.zero(::Type{__m128i}) = __m128i(zero(UInt64), zero(UInt64))
Base.one(::Type{__m128i}) = __m128i(zero(UInt64), one(UInt64))
Base.xor(a::__m128i, b::__m128i) = llvmcall(
    """%3 = xor <2 x i64> %1, %0
    ret <2 x i64> %3""",
    __m128i, Tuple{__m128i, __m128i},
    a, b
)
(+)(a::__m128i, b::__m128i) = llvmcall(
    """%3 = add <2 x i64> %1, %0
    ret <2 x i64> %3""",
    __m128i, Tuple{__m128i, __m128i},
    a, b
)
(+)(a::__m128i, b::Integer) = a + __m128i(UInt128(b))

_aes_enc(a::__m128i, round_key::__m128i) = ccall(
    "llvm.x86.aesni.aesenc",
    llvmcall,
    __m128i, (__m128i, __m128i),
    a, round_key
)
_aes_enc_last(a::__m128i, round_key::__m128i) = ccall(
    "llvm.x86.aesni.aesenclast",
    llvmcall,
    __m128i, (__m128i, __m128i),
    a, round_key
)
_aes_key_gen_assist(a::__m128i, ::Val{R}) where R = ccall(
    "llvm.x86.aesni.aeskeygenassist",
    llvmcall,
    __m128i, (__m128i, UInt8),
    a, R
)

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

@inline inc_counter!(r::AbstractAESNI4x) = (r.ctr1 += one(__m128i); r)

const R123_USE_AESNI = Ref{Union{Nothing,Bool}}(nothing)

"True when AES-NI has been enabled."
function use_aesni()
    if R123_USE_AESNI[] ≡ nothing
        R123_USE_AESNI[] = try
            cmd = Base.julia_cmd()
            push!(
                cmd.exec, "-e",
                "const __m128i = NTuple{2, VecElement{UInt64}};" *
                "@assert ccall(\"llvm.x86.aesni.aeskeygenassist\", " *
                "llvmcall, __m128i, (__m128i, UInt8), " *
                "__m128i((0x0123456789123450, 0x9876543210987654)), 0x1) ≡ " *
                "__m128i((0x857c266f7c266e85, 0x2346382146382023))"
            )
            success(cmd)
        catch e
            false
        end
    end
    R123_USE_AESNI[]
end
function check_use_aesni()
    if !use_aesni()
        error("AES-NI is not enabled, so AESNI and ARS are not available.")
    end
end
