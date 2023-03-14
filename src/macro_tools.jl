# https://github.com/thautwarm/MLStyle-Playground/blob/master/StaticCapturing.jl
function get_bindings(pattern::Expr)
    result = Set{Symbol}()
    _analyze(pat, is_literal=true) = @match pat begin
        ::QuoteNode => _analyze(pat.value, true)
        if is_literal end && Expr(:$, args...) => foreach(x -> _analyze(x, false), args)
        if is_literal end && Expr(_, args...) => foreach(_analyze, args)
        if is_literal end && _ => nothing
        ::Symbol => (push!(result, pat); nothing)
        Expr(:quote, args...) => foreach(x -> _analyze(x, true), args)
        :(Do($(args...))) => foreach(args) do arg
            @match arg begin
                Expr(:kw, key::Symbol, value) => push!(result, key)
                _ => nothing
            end
        end
        :($a || $b) => begin
            _analyze(a, false)
            _analyze(b, false)
            nothing
        end
        # type pattern
        Expr(:(::), v, _...) => _analyze(v, false)
        # dict pattern
        :(Dict($(args...))) => foreach(args) do arg
            @match arg begin
                :($_ => $v) => _analyze(v, false)
                _ => nothing
            end
        end
        # app pattern
        :($_($(args...))) => foreach(x -> _analyze(x, false), args)
        # other expr
        Expr(_, args...) => foreach(x -> _analyze(x, false), args)
        _ => nothing
    end
    _analyze(pattern)
    result
end

const rmlines = @λ begin
    ::LineNumberNode -> nothing
    Expr(head, args...) -> Expr(head, filter(!isnothing, map(rmlines, args))...)
    s -> s
end

"""
    @capture(expr, pattern)

Capture and bind variables in `pattern` to `expr`.
Similar to `MacroTools.@capture`, but using static analysis.

It supports the syntax of `@match` and `@λ` in `MLStyle.jl`.
"""
@public macro capture(expr, pattern)
    bindings = get_bindings(pattern)
    t = gensym()
    quote
        $(esc(t)) = @match rmlines($(esc(expr))) begin
            $(Expr(:quote, pattern)) => $(Expr(:tuple, bindings...))
            _ => nothing
        end
        if isnothing($(esc(t)))
            false
        else
            $(esc(:($(Expr(:tuple, bindings...)) = $t)))
            true
        end
    end
end

@public macro forward(member, methods)
    @capture member $T.$field
    methods = methods.args
    Expr(:block, (
        Expr(
            :(=),
            :(($(esc(f)))(t::$(esc(T)), args...; kwargs...)),
            Expr(:block,
                __source__,
                :($(esc(f))(t.$field, args...; kwargs...))
            )
        )
        for f in methods
    )...)
end