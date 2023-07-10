using Test
using Kirei

module M

using Kirei

@public f1() = 1
@public begin
    @inline function f2()
        2
    end
    """
        m3()

    Some docs.
    """
    macro m3()
        3
    end
    const c4::Int = 4
    global g5 = 5
    v6 = 6
end
v7 = 7
@public v7
const private8 = 8
@public @krecord struct R9
    x::Int = 0
end
@public @data D10 begin
    D10S(::String)
    D10F(a::Float64)
end
end # module M

@testset "@public" begin
    using .M
    @test f1() == 1
    @test f2() == 2
    @test @eval @m3() == 3
    @test c4 == 4
    @test g5 == 5
    @test v6 == 6
    @test v7 == 7
    @test_throws UndefVarError private8
    @test R9().x == 0
    @test D10S("a") isa D10
    @test D10F(3).a == 3
end
