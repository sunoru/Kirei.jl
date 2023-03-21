"""
    capture_name(expr, [__module__])

Capture the name in a definition expression.
"""
function capture_name(expr, __module__::Module=Main)
    name = @match expr begin
        ::Symbol => expr
        Expr(:(::), v, _) => v
        Expr(:(=), v, _) => v
        Expr(:function, f, _...) => f
        Expr(:macro, m, _...) => Symbol("@", capture_name(m, __module__))
        Expr(:const, c) => c
        Expr(:global, g) => g
        Expr(:call, f, _...) => f
        Expr(:struct, _, t, __...) => t
        Expr(:(<:), t, _) => t
        Expr(:abstract, t) => t
        Expr(:macrocall, _...) => macroexpand(__module__, expr)
        Expr(:block, _...) => nothing
        Expr(:where, v, _) => v
    end
    if isnothing(name) || name isa Symbol
        name
    else
        capture_name(name, __module__)
    end
end

"""
    @public expr

Automatically export the name defined in `expr`.
"""
macro public(expr)
    function _public(expr)
        name = capture_name(expr, __module__)
        isnothing(name) || return quote
            export $name
            Core.@__doc__ $(esc(expr))
        end
        @assert expr.head ≡ :block "Unsupported expression: @public $expr"
        Expr(:block,
            (x isa LineNumberNode ? x : _public(x) for x in expr.args)...
        )
    end
    _public(expr)
end

export @public
