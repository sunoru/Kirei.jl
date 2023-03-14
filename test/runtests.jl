using Test
using Kirei

@testset "Kirei.jl" begin
    include("./macro_tools.jl")
    include("./target.jl")
    include("./public.jl")
    include("./kcall.jl")
end
