module Kirei

include("./_Common.jl")
using ._Common

include("./macro_tools/public.jl")
include("./macro_tools/type.jl")
include("./macro_tools/destruct.jl")
include("./macro_tools/function.jl")

include("./tools/platform.jl")
include("./tools/function.jl")
include("./tools/ffi.jl")

include("./Common.jl")

end # module Kirei
