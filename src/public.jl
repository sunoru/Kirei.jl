function _capture_name(expr)
    name = @match_expr expr begin
        (v_::_) => v
        (f_(__) = _) => f
        (function f_(__) _ end) => f
        (macro m_(__) _ end) => Symbol("@", m)
        (const c_ = _) => c
        (global g_) => g
        (global g_ = _) => g
        (v_ = _) => v
        (s_Symbol) => s
    end
    if isnothing(name) || name isa Symbol
        name
    else
        _capture_name(name)
    end
end

function _public(expr)
    name = _capture_name(expr)
    isnothing(name) || return quote
        export $name
        $(esc(expr))
    end
    @assert expr.head ≡ :block "Unsupported expression: @public $expr"
    quote
        $((x isa LineNumberNode ? x : _public(x) for x in expr.args)...)
    end
end

"""
    @public expr

Automatically export the name defined in `expr`.
"""
macro public(expr)
    _public(expr)
end
