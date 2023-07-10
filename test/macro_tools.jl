using Test
using Kirei

@krecord struct Foo1
    x::Union{Foo1,String}
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

end
