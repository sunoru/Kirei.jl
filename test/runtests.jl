using Test
using Kirei

@testset "Kirei.jl" begin
    include("./target.jl")
    include("./public.jl")
    include("./kcall.jl")
end
