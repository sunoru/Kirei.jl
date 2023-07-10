module Kirei

include("./Common.jl")
using .Common

include("./reexports.jl")

include("./macro_tools/public.jl")
include("./macro_tools/type.jl")
include("./macro_tools/destruct.jl")
include("./macro_tools/function.jl")

include("./tools/platform.jl")
include("./tools/function.jl")
include("./tools/ffi.jl")

end # module Kirei
