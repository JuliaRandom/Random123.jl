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

export Threefry2x, Threefry4x
include("threefry.jl")

export Philox2x, Philox4x
include("philox.jl")

export R123_USE_AESNI

"True when AES-NI has been enabled."
const R123_USE_AESNI = try
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

@static if R123_USE_AESNI
    export AESNI1x, AESNI4x
    export ARS1x, ARS4x
    include("./aesni_common.jl")
    include("./aesni.jl")
    include("./ars.jl")
else
    @warn "AES-NI is not enabled, so AESNI and ARS are not available."
end

end
