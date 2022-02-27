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

"True when AES-NI has been enabled."
const R123_USE_AESNI = Ref(false)
export R123_USE_AESNI
export AESNI1x, AESNI4x
export ARS1x, ARS4x

function __init__()

    aesni_dir = joinpath(dirname(@__FILE__), "aesni")
    R123_USE_AESNI[] = try
        cmd = Base.julia_cmd()
        script = joinpath(aesni_dir, "has_aesni.jl")
        push!(cmd.exec, script)
        success(cmd)
    catch
        false
    end
    
    if R123_USE_AESNI[]
        include(joinpath(aesni_dir, "module.jl"))
        @eval using ._AESNIModule
    else
        @warn "AES-NI is not enabled, so AESNI and ARS are not available."
    end

    nothing
end

end
