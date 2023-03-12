function capture_name(expr, module_)
    name = @match expr begin
        ::Symbol => expr
        Expr(:(::), v, _) => v
        Expr(:(=), v, _) => v
        Expr(:function, f, _...) => f
        Expr(:macro, m, _...) => Symbol("@", capture_name(m, module_))
        Expr(:const, c) => c
        Expr(:global, g) => g
        Expr(:call, f, _...) => f
        Expr(:(<:), t, _) => t
        Expr(:abstract, t) => t
        Expr(:macrocall, _...) => macroexpand(module_, expr)
        Expr(:block, _...) => nothing
    end
    if isnothing(name) || name isa Symbol
        name
    else
        capture_name(name, module_)
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
        quote
            $((x isa LineNumberNode ? x : _public(x) for x in expr.args)...)
        end
    end
    _public(expr)
end

export @public
