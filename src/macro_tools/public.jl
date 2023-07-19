getdef(expr, __module__::Module=Main) = error("Unsupported: $expr")
getdef(ref::GlobalRef, __module__::Module=Main) = getfield(ref.mod, ref.name)
getdef(s::Symbol, __module__::Module=Main) = getfield(__module__, s)
getdef(qn::QuoteNode, __module__::Module=Main) = getdef(qn.value, __module__)
function getdef(m::Expr, __module__::Module=Main)
    @assert m.head ≡ :. "Unsupported expr: $m"
    mod = getfield(__module__, m.args[1])
    getdef(m.args[2], mod)
end
"""
    @declared_names @macro(args...) = body

Declare the names defined in a macro.

Example:

```julia
@declared_names Kirei.@krecord(body) = body
@declared_names MLStyle.@data(name, body) = [name, body]
@declared_names @enum(args...) = args
```
"""
macro declared_names(expr)
    @assert expr.head ≡ :(=) && expr.args[1].head ≡ :macrocall "Incorrect use of `@declared_names`."
    macro_, line, args... = expr.args[1].args
    T = getdef(macro_, __module__) |> typeof
    body = expr.args[2]
    quote
        function Kirei.macro_declared_names(::$T, args::AbstractVector)
            $line
            function _get_names($(args...))
                $body
            end
            _get_names(args...)
        end
    end
end

macro_declared_names(::Function, ::AbstractVector) = nothing
@declared_names Core.@doc(_doc, target) = target
@declared_names MLStyle.@data(name, body) = [name, body]

function _capture_names_macrocall(expr, __module__::Module=Main)
    macro_ = expr.args[1]
    cpt(x) = capture_names(x, __module__)
    m = getdef(macro_, __module__)
    name = macro_declared_names(m, expr.args[3:end])
    isnothing(name) && return cpt(macroexpand(__module__, expr, recursive=false))
    try
        return vcat(cpt.(name)...)
    catch
        cpt(name)
    end
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
                capture_names(x, __module__)
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
