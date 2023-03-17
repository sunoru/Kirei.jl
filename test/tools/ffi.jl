using Test
using Kirei

@testset "FFI tools" begin

    @testset "@kcall" begin
        @test nothing ≡ @kcall jl_yield()
        ptr = @kcall malloc(8::Csize_t)::Ptr{Cvoid}
        @test ptr isa Ptr{Cvoid}
        @test nothing ≡ @kcall free(ptr)
        @test 1 == @kcall :libjulia jl_ver_major()::Cint
    end

end
