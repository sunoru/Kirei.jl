using Test
using Kirei

struct Foo2
    s::String
end

@testset "Function tools" begin

    @testset "@forward" begin
        @forward Foo2.s Base.length, Base.show(io::IO)
        foo = Foo2("123")
        @test length(foo) ≡ 3
        @test string(foo) ≡ "\"123\""

        struct WithTypeParam{T} end
        WithTypeParam{T}(b, a) where {T} = b + parse(T, a)

        @forward Foo2.s WithTypeParam{T}(b) where {T}
        @test 124 ≡ WithTypeParam{Int}(1, foo)
        @test 125.0 ≡ WithTypeParam{Float64}(2, foo)
    end

    @testset "@default" begin
        @head_default f1([T::Type=Float64], a, b=5) = T(a + b)
        @test f1(2, 3) ≡ 5.0
        @test f1(Int, 2) ≡ 7
        @test f1(2) ≡ 7.0

        f2(io::IO, ::Type{T}, xs...) where T = (write(io, T.(xs)...); io)
        @head_default f2([io::IO=IOBuffer()], [T::Type=Float64], xs...)
        s = f2(1, 2, 3)
        @test reinterpret(Float64, take!(s)) == [1.0, 2.0, 3.0]
        s = f2(Int, 1, 2.0)
        @test reinterpret(Int, take!(s)) == [1, 2]
        p = IOBuffer()
        f2(p, 1)
        @test reinterpret(Float64, take!(p)) == [1.0]

        @head_default f3([a1::Int=0, a2::Int=0], a3::Float64) = a1 + a2 * a3
        @test f3(1, 2, 3.0) ≡ 7.0
        @test f3(3.0) ≡ 0.0
        @test_throws MethodError f3(1, 3.0)
    end
end
