using Test
using Kirei

module M

using Kirei

@public f1() = 1
@public begin
    function f2()
        2
    end
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
end
