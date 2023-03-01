module Kirei

export @target, @target_os, @target_arch
export @public
export @kcall

include("./Common.jl")
using .Common

include("./target.jl")
include("./public.jl")
include("./kcall.jl")

end # module Kirei
