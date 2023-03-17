using Test
using Kirei

@testset "Platform tools" begin

    @testset "@target" begin
        @target os = windows, linux begin
            @test Sys.iswindows() || Sys.islinux()
        end
        @target os = macos arch = (x86_64) begin
            @test Sys.isapple() && Sys.ARCH ≡ :x86_64
        end
        @target_os windows, macos begin
            @test Sys.iswindows() || Sys.isapple()
        end
        @target_arch x86_64 begin
            @test Sys.ARCH ≡ :x86_64
        end
    end

end
