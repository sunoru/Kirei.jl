function _capture_names_macrocall(expr, __module__::Module=Main)
    macro_ = expr.args[1]
    if macro_ ≡ GlobalRef(Core, Symbol("@doc"))
        return capture_names(expr.args[end])
    end
    if macro_ isa Symbol
        m = getfield(__module__, macro_)
        if m === getfield(Kirei, Symbol("@krecord"))
            return capture_names(expr.args[end])
        elseif m === getfield(Kirei, Symbol("@data"))
            return [
                expr.args[end - 1],
                capture_names(expr.args[end])...
            ]
        end
    end
    capture_names(macroexpand(__module__, expr))
end

"""
    capture_names(expr, [__module__])

Capture the names in a definition expression.
"""
function capture_names(expr, __module__::Module=Main)
    name = @match expr begin
        ::Symbol => expr
        Expr(:(::), v, _) => v
        Expr(:(=), v, _) => v
        Expr(:function, f, _...) => f
        Expr(:macro, m, _...) => Symbol("@", only(capture_names(m, __module__)))
        Expr(:const, c) => c
        Expr(:global, g) => g
        Expr(:call, f, _...) => f
        Expr(:struct, _, t, __...) => t
        Expr(:(<:), t, _) => t
        Expr(:abstract, t) => t
        Expr(:macrocall, _...) => _capture_names_macrocall(expr, __module__)
        Expr(:block, lines...) => vcat(
            (
                capture_names(x)
                for x in lines
                if !(x isa LineNumberNode)
            )...
        )
        Expr(:where, v, _) => v
        _ => nothing
    end
    if isnothing(name) || name isa Vector
        name
    elseif name isa Symbol
        [name]
    else
        capture_names(name, __module__)
    end
end

"""
    @public expr

Automatically export the name defined in `expr`.
"""
macro public(expr)
    function _public(expr)
        names = capture_names(expr, __module__)
        @assert !isnothing(names) "Unsupported expression: @public $expr"
        quote
            export $(names...)
            Core.@__doc__ $(esc(expr))
        end
    end
    _public(expr)
end

export @public
