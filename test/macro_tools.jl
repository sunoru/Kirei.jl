using Test
using Kirei

@testset "Macro Tools" begin
    expr = :(a + b)
    m = @capture expr $a + $b
    @test m
    @test (a, b) ≡ (:a, :b)
    m = @capture expr $a
    @test m
    @test expr ≡ a
    @test !(@capture expr -$a)
    # struct Foo
    #     s::String
    # end
    # @forward Foo.s Base.length, Base.getindex
    # foo = Foo("abc")
    # @test length(foo) ≡ 3
    # @test foo[1] ≡ 'a'
end
