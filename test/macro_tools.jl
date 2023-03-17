using Test
using Kirei.Common

@as_record struct Foo1
    x::Union{Foo1,String}
end
struct Foo2
    s::String
end

@testset "Macro Tools" begin

    @testset "@destruct" begin

        @destruct (a, b, (c, d, (5,))) = (1, 2, (3, 4, (5,)))
        @test (a, b, c, d) == (1, 2, 3, 4)

        @destruct [1, pack..., t] = [1, 2, 3, 4]
        @test pack == [2, 3]
        @test t == 4


        foo = Foo1(Foo1("abc"))
        result = @destruct Foo1(x=Foo1(x=s)) = foo
        @test result ≡ foo
        @test s == "abc"
        @test !isdefined(Main, :x)

        function f(expr)
            @destruct :($(sa::Symbol) + $(sb::Symbol)) = expr
            sa, sb
        end
        expr = :(x + y)
        @test f(expr) ≡ (:x, :y)
        @inferred f(expr)

        @test_throws ErrorException @destruct [x, y] = [1, 2, 3]
    end

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
