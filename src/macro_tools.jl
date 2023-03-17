function get_bindings(pattern::Expr, __module__::Module=Main)
    result = Set{Symbol}()
    _analyze(pat, is_literal) = @switch pat begin
        @case ::QuoteNode
            _analyze(pat.value, true)
        @case if is_literal end && Expr(:$, args...)
            foreach(x -> _analyze(x, false), args)
        @case if is_literal end && Expr(_, args...)
            foreach(x -> _analyze(x, true), args)
        @case if is_literal end && _
        @case :_
        @case ::Symbol && if isdefined(__module__, pat) && MLStyle.is_enum(getfield(__module__, pat)) end
            # nothing
        @case ::Symbol
            push!(result, pat)
        @case Expr(:quote, args...)
            foreach(x -> _analyze(x, true), args)
        @case :(Do($(args...)))
            foreach(args) do arg
                @when let Expr(:kw, key::Symbol, _) = arg
                    push!(result, key)
                end
            end
        @case :($a || $b)
            _analyze(a, false)
            _analyze(b, false)
        # extract fields
        @case Expr(:kw, _, v)
            _analyze(v, false)
        @case Expr(:(::), v, _...)
            _analyze(v, false)
        # dict pattern
        @case :(Dict($(args...)))
            foreach(args) do arg
                @when let :($_ => $v) = arg
                    _analyze(v, false)
                end
            end
        # app pattern
        @case :($_($(args...)))
            foreach(x -> _analyze(x, false), args)
        # other expr
        @case Expr(_, args...)
            foreach(x -> _analyze(x, false), args)
        @case _
    end
    _analyze(pattern, false)
    result
end

"""
    @destruct lhs = rhs [err_msg]

Destruct `rhs` into `lhs`. Similar to `@when let lhs = rhs`, but the destructed
values are available in the current scope, and it throws an error if the pattern
does not match.
"""
@public macro destruct(expr, err_msg=nothing)
    lhs, rhs = @match expr begin
        Expr(:(=), lhs, rhs) => (lhs, rhs)
        _ => error("Usage: @destruct lhs = rhs")
    end
    bindings = get_bindings(lhs, __module__)
    binding_tuple = Expr(:tuple, bindings...)
    if isnothing(err_msg)
        err_msg = :("Failed to destruct: $(result)")
    end
    quote
        result = $(esc(rhs))
        $(esc(binding_tuple)) = @when let $lhs = result
            $(binding_tuple)
        @otherwise
            error($err_msg)
        end
        result
    end
end

function gen_forward(Typ, field, methods, __source__)
    defs = map(methods) do method
        method, type_params = @when let :($m where $(T...)) = method
            m, T
        @otherwise
            method, []
        end
        f, prefix_args = @when let :($f($(args...))) = method
            f, args
        @otherwise
            method, []
        end
        f = esc(f)
        prefix_args = map(prefix_args) do arg
            @match arg begin
                ::Symbol => arg
                :(::$T) => :($(gensym())::$(esc(T)))
                :($s::$T) => :($s::$(esc(T)))
            end
        end
        prefix_argnames = map(prefix_args) do arg
            @match arg begin
                ::Symbol => arg
                :($s::$_) => s
            end
        end
        args, kwargs = gensym(), gensym()
        Expr(
            :(=),
            :(($f)($(prefix_args...), t::$(esc(Typ)), $args...; $kwargs...) where $(esc.(type_params)...)),
            Expr(:block,
                __source__,
                :(($f)($(prefix_argnames...), t.$field, $args...; $kwargs...))
            )
        )
    end
    Expr(:block, defs...)
end

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