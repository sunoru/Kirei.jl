function get_bindings(pattern::Expr)
    result = Set{Symbol}()
    _analyze(pat, is_literal=true) = @match pat begin
        if is_literal end && Expr(:$, args...) => foreach(x -> _analyze(x, false), args)
        if is_literal end && Expr(_, args...) => foreach(_analyze, args)
        if is_literal end && _ => nothing
        ::Symbol => (push!(result, pat); nothing)
    end
    _analyze(pattern)
    result
end

"""
"""
@public macro capture(expr, pattern)
    bindings = get_bindings(pattern)
    t = gensym()
    quote
        $t = @match $expr begin
            $(Expr(:quote, pattern)) => $(Expr(:tuple, bindings...))
            _ => nothing
        end
        if isnothing($t)
            false
        else
            $(Expr(:tuple, bindings...)) = $t
            true
        end
    end |> esc
end

@public macro forward(member, methods)

end
