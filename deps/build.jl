disabled() = get(ENV, "R123_DISABLE_AESNI", "") != ""

using CpuId
has_aesni() = cpufeature(:AES)

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
