using Test
using Kirei

@testset "Kirei.jl" begin

    include("./public.jl")
    include("./macro_tools.jl")

    include("./tools/platform.jl")
    include("./tools/function.jl")
    include("./tools/ffi.jl")

end
