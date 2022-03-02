import Random: rand, seed!
import RandomNumbers: AbstractRNG

const R123Array1x{T<:Union{UInt128}}        = NTuple{1, T}
const R123Array2x{T<:Union{UInt32, UInt64}} = NTuple{2, T}
const R123Array4x{T<:Union{UInt32, UInt64}} = NTuple{4, T}

"The base abstract type for RNGs in [Random123 Family](@ref)."
abstract type AbstractR123{T<:Union{UInt32, UInt64, UInt128}} <: AbstractRNG{T} end

"RNG that generates one number at a time."
abstract type R123Generator1x{T} <: AbstractR123{T} end
"RNG that generates two numbers at a time."
abstract type R123Generator2x{T} <: AbstractR123{T} end
"RNG that generates four numbers at a time."
abstract type R123Generator4x{T} <: AbstractR123{T} end

_value(r::AbstractR123{T}, i = 1, ::Type{T2} = T) where {T, T2} = unsafe_load(Ptr{T2}(pointer_from_objref(r)), i)

"Set the counter of a Random123 RNG."
@inline function set_counter!(r::R123Generator1x{T}, ctr::Integer) where T <: UInt128
    r.ctr = ctr % T
    random123_r(r)
    r
end

@inline function set_counter!(
    r::R123Generator2x{T},
    (ctr1, ctr2)::NTuple{2, Integer}
) where T <: Union{UInt32, UInt64}
    r.p = 0
    r.ctr1 = ctr1 % T
    r.ctr2 = ctr2 % T
    random123_r(r)
    r
end

@inline function set_counter!(
    r::R123Generator4x{T},
    (ctr1, ctr2, ctr3, ctr4)::NTuple{4, Integer}
) where T <: Union{UInt32, UInt64}
    r.p = 0
    r.ctr1 = ctr1 % T
    r.ctr2 = ctr2 % T
    r.ctr3 = ctr3 % T
    r.ctr4 = ctr4 % T
    random123_r(r)
    r
end
@inline set_counter!(r::R123Generator2x, ctr::Integer) = set_counter!(r, (ctr, 0))
@inline set_counter!(r::R123Generator4x, ctr::Integer) = set_counter!(r, (ctr, 0, 0, 0))

@inline inc_counter!(r::R123Generator1x{T}) where T = (r.ctr += one(T); r)
@inline function inc_counter!(r::R123Generator2x{T}) where T
    r.ctr1 += one(T)
    r.ctr1 == zero(T) && (r.ctr2 += one(T))
    r
end
@inline function inc_counter!(r::R123Generator4x{T}) where T
    r.ctr1 += one(T)
    if r.ctr1 == zero(T)
        r.ctr2 += one(T)
        if r.ctr2 == zero(T)
            r.ctr3 += one(T)
            if r.ctr3 == zero(T)
                r.ctr4 += one(T)
            end
        end
    end
    r
end

@inline function rand(r::R123Generator1x{T}, ::Type{T}) where T <: UInt128
    r.ctr += one(T)
    random123_r(r)
    _value(r)
end

@inline function rand(r::R123Generator2x{T}, ::Type{T}) where T <: Union{UInt32, UInt64}
    to = one(T)
    if r.p == 1
        inc_counter!(r)
        random123_r(r)
        r.p = 0
        return r.x2
    end
    r.p = 1
    r.x1
end

@inline function rand(r::R123Generator4x{T}, ::Type{T}) where T <: Union{UInt32, UInt64}
    if r.p == 4
        inc_counter!(r)
        random123_r(r)
        r.p = 0
    end
    r.p += 1
    _value(r, r.p)
end

@inline function rand(r::R123Generator1x{T}, ::Type{R123Array1x{T}}) where T <: UInt128
    inc_counter!(r)
    random123_r(r)
end

@inline function rand(r::R123Generator2x{T}, ::Type{R123Array2x{T}}) where T <: Union{UInt32, UInt64}
    if r.p > 0
        inc_counter!(r)
    end
    ret = random123_r(r) # which returns a Tuple{T, T}
    r.p = 1
    ret
end

@inline function rand(r::R123Generator4x{T}, ::Type{R123Array4x{T}}) where T <: Union{UInt32, UInt64}
    if r.p > 0
        inc_counter!(r)
    end
    ret = random123_r(r)
    r.p = 4
    ret
end

for (T, DT) in ((UInt32, UInt64), (UInt64, UInt128))
    @eval @inline function rand(r::R123Generator2x{$T}, ::Type{$DT})
        if r.p == 1
            inc_counter!(r)
            random123_r(r)
        end
        r.p = 1
        _value(r, 1, $DT)
    end
end

@inline function rand(r::R123Generator4x{UInt32}, ::Type{UInt128})
    if r.p > 0
        inc_counter!(r)
        random123_r(r)
    end
    r.p = 4
    _value(r, 1, UInt128)
end

"Do one iteration and
return the result tuple of a Random123 RNG object."
random123_r
