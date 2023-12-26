__precompile__(true)

"""
The module for [Random123 Family](@ref).

Provide 8 RNG types:

- [`Threefry2x`](@ref)
- [`Threefry4x`](@ref)
- [`Philox2x`](@ref)
- [`Philox4x`](@ref)
- [`AESNI1x`](@ref)
- [`AESNI4x`](@ref)
- [`ARS1x`](@ref)
- [`ARS4x`](@ref)
"""
module Random123

using RandomNumbers

export set_counter!
include("common.jl")

export Threefry2x, Threefry4x, threefry
include("threefry.jl")

export Philox2x, Philox4x, philox
include("philox.jl")

export R123_USE_AESNI

"True when x86 AES-NI instructiona have been detected."
const R123_USE_X86_AES_NI::Bool = @static if Sys.ARCH ≡ :x86_64 || Sys.ARCH ≡ :i686
        try
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
else
    false
end

"True when AES-acceleration instructions have been detected."
const R123_USE_AESNI::Bool = R123_USE_X86_AES_NI

@static if R123_USE_AESNI
    export AESNI1x, AESNI4x, aesni
    export ARS1x, ARS4x, ars
else
    @warn "AES-acceleration instructions have not been detected, so the related RNGs (AESNI and ARS) are not available."
end

@static if R123_USE_X86_AES_NI
    include("./x86/aesni_common.jl")
    include("./x86/aesni.jl")
    include("./x86/ars.jl")
end

end
