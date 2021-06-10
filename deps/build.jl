disabled() = get(ENV, "R123_DISABLE_AESNI", "") != ""

const __m128i = NTuple{2, VecElement{UInt64}}
has_aesni() = try
    ccall(
        "llvm.x86.aesni.aeskeygenassist", llvmcall, __m128i, (__m128i, UInt8),
        __m128i((0x0123456789123450, 0x9876543210987654)), 0x1
    ) ≡ __m128i((0x857c266f7c266e85, 0x2346382146382023))
catch e
    false
end

const filename = joinpath(dirname(@__FILE__), "aes-ni")
isfile(filename) && rm(filename)

if disabled()
    @info "AES-NI is disabled."
elseif has_aesni()
    @info "AES-NI is enabled."
    touch(filename)
else
    @info "AES-NI is not supported."
end
