using Test
using Kirei

@testset "Macro Tools" begin
    @testset "@capture" begin
        expr = quote
            ff(1, "2")
        end
        let m = @capture expr begin
                $(:($f = $args) || :($f($(args...))))
            end
            @test m
            @test f ≡ :ff
            @test args == [1, "2"]
        end

        function f(expr)
            m = @capture expr $(a::Symbol) + $(b::Symbol)
            m, a, b
        end
        @inferred f(:(x + y))
        @test !(@capture expr -$a)
    end

    @testset "@forward" begin
        struct Foo
            s::String
        end
        @forward Foo.s Base.length, Base.getindex
        foo = Foo("abc")
        @test length(foo) ≡ 3
        @test foo[1] ≡ 'a'
        f(s::String) = s[2]
        @forward Foo.s f
        f(foo) ≡ 'b'
    end
end
