using Test
using Kirei

# `@generated` should be top-level due to world age issues
@generated function sprintf(fmt, varargs...; buffer_size=30)
    quote
        buffer = zeros(UInt8, buffer_size)
        len = $(@variadic_ccall sprintf(
            buffer::Ptr{Cchar},
            fmt::Cstring;
            varargs...
        )::Cint)
        String(view(buffer, 1:len))
    end
end

@testset "FFI tools" begin

    @testset "@kcall" begin
        @test nothing ≡ @kcall jl_yield()
        ptr = @kcall malloc(8::Csize_t)::Ptr{Cvoid}
        @test ptr isa Ptr{Cvoid}
        @test nothing ≡ @kcall free(ptr)
        @test 1 == @kcall :libjulia jl_ver_major()::Cint
    end

    @testset "@variadic_ccall" begin
        @test sprintf("Hello, %s!", "world") == "Hello, world!"
        @test sprintf("%s, %d!", "Hello", 123) == "Hello, 123!"
        @test sprintf("%.3f, %s, %d!", 0.1234, "Hello", 123) == "0.123, Hello, 123!"
    end
end
