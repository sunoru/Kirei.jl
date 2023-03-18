function gen_forward(Typ, field, methods, __source__)
    defs = map(methods) do method
        method, type_params = @when let :($m where $(T...)) = method
            m, T
        @otherwise
            method, []
        end
        f, pre_args = @when let :($f($(args...))) = method
            f, args
        @otherwise
            method, []
        end
        f = esc(f)
        pre_args = map(pre_args) do arg
            @match arg begin
                ::Symbol => arg
                :(::$T) => :($(gensym())::$(esc(T)))
                :($s::$T) => :($s::$(esc(T)))
            end
        end
        pre_argnames = map(pre_args) do arg
            @match arg begin
                ::Symbol => arg
                :($s::$_) => s
            end
        end
        args, kwargs = gensym(), gensym()
        Expr(
            :(=),
            :(($f)($(pre_args...), t::$(esc(Typ)), $args...; $kwargs...) where $(esc.(type_params)...)),
            Expr(:block,
                __source__,
                :(($f)($(pre_argnames...), t.$field, $args...; $kwargs...))
            )
        )
    end
    Expr(:block, defs...)
end

"""
    @forward Foo.bar f, g(io::IO), h{T}(::Int, arg2) where T

Forward methods `f`, `g`, `h` of `Foo` to `Foo.bar`.
It is similar to `MacroTools.@forward`, but it supports arguments before the given type.

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

"""
    @leading_default f([io::IO=stdout], a::Int, b=0)

Generate a function `f` that has default values for the leading arguments.
Note that you need to specify the types of some arguments to prevent ambiguity.

The above is equivalent to
```julia
f(io::IO, a::Int) = f(io, a, 0)
f(a::Int, b) = f(stdout, a, b)
f(a::Int) = f(stdout, a, 0)
```

You can also use `@leading_default` before a function definition.
"""
@public macro leading_default(funcdef)
    funcdef = FuncDef(funcdef)

end
