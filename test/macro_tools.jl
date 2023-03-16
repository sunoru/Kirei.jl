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
        @forward Foo2.s Base.length, Base.getindex

        foo = Foo2("abc")
        @test length(foo) ≡ 3
        @test foo[1] ≡ 'a'
        f(s::String) = s[2]
        @forward Foo2.s f
        f(foo) ≡ 'b'
    end
end
