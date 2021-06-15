disabled() = get(ENV, "R123_DISABLE_AESNI", "") != ""

const deps_dir = dirname(@__FILE__)

has_aesni() = try
    cmd = Base.julia_cmd()
    push!(cmd.exec, joinpath(deps_dir, "has_aesni.jl"))
    run(cmd)
    true
catch
    false
end

const filename = joinpath(deps_dir, "aes-ni")
isfile(filename) && rm(filename)

if disabled()
    @info "AES-NI is disabled."
elseif has_aesni()
    @info "AES-NI is enabled."
    touch(filename)
else
    @info "AES-NI is not supported."
end
