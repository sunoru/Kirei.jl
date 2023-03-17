module Kirei

include("./_Common.jl")
using ._Common

include("./public.jl")
include("./macro_tools.jl")

include("./tools/platform.jl")
include("./tools/function.jl")
include("./tools/ffi.jl")

include("./Common.jl")

end # module Kirei
