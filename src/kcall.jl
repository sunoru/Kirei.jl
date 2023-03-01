function _kcall(lib, expr)
    expr = @match_expr expr begin
        (f_(args__)) => :($f($(args...))::Cvoid)
        (f_(args__)::t_) => :($f($(args...))::$(esc(t)))
        _ => error("Invalid expression for @kcall: $expr")
    end
    @capture expr f_(args__)::T_
    if !isnothing(lib) && f isa Symbol
        f = :($lib.$f)
    end
    for i in eachindex(args)
        arg = args[i]
        args[i] = @match_expr arg begin
            (a_::t_) => :($(esc(a))::$(esc(t)))
            (a_) => :($(esc(a))::Ptr{Cvoid})
        end
    end
    :(@ccall $f($(args...))::$T)
end

"""
    @kcall [lib] cfunc(arg0::T0, arg1::T1, ...)::TR

Similar to `@ccall`. But it defines typeless arguments as pointers
and typeless return values as `Cvoid`.
"""
macro kcall(lib, expr)
    _kcall(esc(lib), expr)
end

macro kcall(expr)
    _kcall(nothing, expr)
end