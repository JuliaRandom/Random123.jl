const __m128i = NTuple{2, VecElement{UInt64}}
@assert ccall(
    "llvm.x86.aesni.aeskeygenassist", llvmcall, __m128i, (__m128i, UInt8),
    __m128i((0x0123456789123450, 0x9876543210987654)), 0x1
) ≡ __m128i((0x857c266f7c266e85, 0x2346382146382023))
