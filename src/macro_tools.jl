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
        # type pattern
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
    @destruct lhs = rhs

Destruct `rhs` into `lhs`. Similar to `@when let lhs = rhs`, but the destructed
values are available in the current scope, and it throws an error if the pattern
does not match.
"""
@public macro destruct(expr)
    lhs, rhs = @match expr begin
        Expr(:(=), lhs, rhs) => (lhs, rhs)
        _ => error("Usage: @destruct lhs = rhs")
    end
    bindings = get_bindings(lhs, __module__)
    binding_tuple = Expr(:tuple, bindings...)
    quote
        result = $(esc(rhs))
        $(esc(binding_tuple)) = @when let $lhs = result
            $(binding_tuple)
        @otherwise
            error("Failed to destruct: $(result)")
        end
        result
    end
end

"""
    @forward Foo.bar f, g, h

Forward methods `f`, `g`, `h` of `Foo` to `Foo.bar`.

For example, the above is equivalent to
```julia
f(x::Foo, args...; kwargs...) = f(x.bar, args...; kwargs...)
g(x::Foo, args...; kwargs...) = g(x.bar, args...; kwargs...)
h(x::Foo, args...; kwargs...) = h(x.bar, args...; kwargs...)
```

It is similar to `MacroTools.@forward`.
"""
@public macro forward(member, methods)
    @destruct :($T.$field) = member
    methods = @match methods begin
        Expr(:tuple, args...) => esc.(args)
        _ => [esc(methods)]
    end
    Expr(:block, (
        Expr(
            :(=),
            :(($f)(t::$(esc(T)), args...; kwargs...)),
            Expr(:block,
                __source__,
                :(($f)(t.$field, args...; kwargs...))
            )
        )
        for f in methods
    )...)
end