function _kcall(lib, expr)
    f, args, T = @match expr begin
        Expr(:call, f, args...) => (f, args, :Cvoid)
        Expr(:(::), Expr(:call, f, args...), T) => (f, args, esc(T))
        _ => error("Invalid expression for @kcall: $expr")
    end
    if !isnothing(lib) && f isa Symbol
        f = :($lib.$f)
    end
    for i in eachindex(args)
        arg = args[i]
        args[i] = @match arg begin
            Expr(:(::), a, t) => :($(esc(a))::$(esc(t)))
            ::Symbol => :($(esc(arg))::Ptr{Cvoid})
        end
    end
    :(@ccall $f($(args...))::$T)
end

"""
    @kcall [lib] cfunc(arg0::T0, arg1::T1, ...)::TR

Similar to `@ccall`. But it defines typeless arguments as pointers
and typeless return values as `Cvoid`.
"""
@public macro kcall(lib, expr)
    _kcall(esc(lib), expr)
end

macro kcall(expr)
    _kcall(nothing, expr)
end
