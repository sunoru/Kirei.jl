function _parse_kcall(lib, expr; escape=true)
    f, args, T = @match expr begin
        Expr(:call, f, args...) => (f, args, :Cvoid)
        Expr(:(::), Expr(:call, f, args...), T) => (f, args, escape ? esc(T) : T)
        _ => error("Invalid expression for @kcall: $expr")
    end
    if !isnothing(lib) && f isa Symbol
        f = :($lib.$f)
    end
    map_arg(arg) = @match arg begin
        Expr(:parameters, varargs...) => Expr(:parameters, map(map_arg, varargs)...)
        Expr(:(::), a, t) => escape ? :($(esc(a))::$(esc(t))) : :($a::$t)
        ::Symbol => escape ? :($(esc(arg))::Ptr{Cvoid}) : :($arg::Ptr{Cvoid})
        _ => arg
    end
    for i in eachindex(args)
        args[i] = map_arg(args[i])
    end
    (; f, args, T)
end

function _kcall(lib, expr)
    f, args, T = _parse_kcall(lib, expr)
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

function gen_variadic_ccall(lib, expr)
    f, args, T = _parse_kcall(lib, expr, escape=false)
    @destruct [Expr(:parameters, params...), _...] = args "Input is not a variadic call"
    @destruct [_..., :($varargs_sym...)] = params "Input does not have varargs"

    pos_args = args[2:end]
    pos_params = params[1:end - 1]
    body = QuoteNode(:(@ccall $f(
        $(pos_args...);
        $(pos_params...)
    )::$T))

    quote
        varargs = $(esc(varargs_sym))
        varargs = if varargs isa DataType && varargs <: Tuple
            varargs.parameters
        else
            varargs
        end
        vararg_types = [
            t <: AbstractString ? Cstring : t
            for t in varargs
        ]
        len = length(varargs)
        # Copy is needed here
        body = copy($body)
        params = body.args[3].args[1].args[2].args
        for (i, type) in enumerate(vararg_types)
            push!(params, $(Expr(
                :quote,
                :($varargs_sym[$(Expr(:$, :i))]::$(Expr(:$, :type)))
            )))
        end
        body
    end
end

"""
    @variadic_ccall [lib] cfunc(arg0::T0, arg1::T1; varargs...)::TR

Used in a `@generated` function to call a variadic C function.

Only simple types are supported.

Example:

```julia
@generated printf(fmt, varargs...) = @variadic_ccall printf(s::Cstring; varargs...)::Cint
```
"""
@public macro variadic_ccall(lib, expr)
    gen_variadic_ccall(lib, expr)
end
macro variadic_ccall(expr)
    gen_variadic_ccall(nothing, expr)
end
