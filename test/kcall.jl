using Test
using Kirei

@testset "@kcall" begin
    @test nothing ≡ @kcall jl_yield()
    ptr = @kcall malloc(8::Csize_t)::Ptr{Cvoid}
    @test ptr isa Ptr{Cvoid}
    @test nothing ≡ @kcall free(ptr)
end
