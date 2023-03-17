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

end
