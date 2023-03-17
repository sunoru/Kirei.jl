
"""
    @forward Foo.bar f, g(io::IO), h{T}(::Int, arg2) where T

Forward methods `f`, `g`, `h` of `Foo` to `Foo.bar`.
It is similar to `MacroTools.@forward`, but it supports prefix arguments.

For example, the above is equivalent to
```julia
f(x::Foo, args...; kwargs...) = f(x.bar, args...; kwargs...)
g(io::IO, x::Foo, args...; kwargs...) = g(io, x.bar, args...; kwargs...)
h{T}(arg1::Int, arg2, x::Foo, args...; kwargs...) where T = h{T}(arg1, arg2, x.bar, args...; kwargs...)
```
"""
@public macro forward(member, methods)
    @destruct :($Typ.$field) = member "Usage: @forward Foo.bar f, g, h
    See the docstring of @forward for more details."
    methods = @when let Expr(:tuple, ms...) = methods
        ms
    @otherwise
        [methods]
    end
    gen_forward(Typ, field, methods, __source__)
end
