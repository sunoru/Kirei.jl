module Kirei

include("./_Common.jl")
using ._Common

include("./public.jl")
include("./macro_tools.jl")

include("./target.jl")
include("./kcall.jl")

include("./Common.jl")

end # module Kirei
