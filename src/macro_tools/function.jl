@krecord struct FuncArg
    name::Union{Symbol,Nothing} = nothing
    type::Union{Symbol,Expr,Nothing} = nothing
    default::Union{Some{Any},Nothing} = nothing
    splatting::Bool = false
end

function parse_argdef(argdef::Union{Symbol,Expr})
    _analyze(arg) = try
        @match arg begin
            name::Symbol => (; name)
            Expr(:(::), type) => (; type)
            :($name::$type) => (; name, type)
            :($v...) => (; _analyze(v)..., splatting=true)
            Expr(:(=), key, value) || Expr(:kw, key, value) =>
                (; _analyze(key)..., default=Some(value))
            _ => arg
        end
    catch
        arg
    end
    @match _analyze(argdef) begin
        nt::NamedTuple => FuncArg(; nt...)
        x => x
    end
end

@krecord struct FuncDef
    name::Union{Symbol,Nothing} = nothing
    args::Vector{Union{FuncArg,Expr}} = []
    kwargs::Vector{Union{FuncArg,Expr}} = []
    type_params::Vector{Any} = []
    body::Union{Expr,Nothing} = nothing
    line_number::LineNumberNode = LineNumberNode(0, :none)
end

"""
    FuncDef(funcdef::Expr, [__module__], [__source__])

Parse a function definition expression into a `FuncDef` struct.
"""
function FuncDef(funcdef::Expr, __module__::Module=Main, __source__::Union{LineNumberNode,Nothing}=nothing)
    funcdef.head ≡ :macrocall && return FuncDef(macroexpand(__module__, funcdef), __module__, __source__)
    header, body = @match funcdef begin
        Expr(:function, header, body) => (header, body)
        :($header = $body) => (header, body)
        _ => (funcdef, nothing)
    end
    line_number = if isnothing(__source__)
        @match body begin
            Expr(:block, args...) &&
                let i = findfirst(x -> x isa LineNumberNode, args) end &&
                if !isnothing(i) end => args[i]
            _ => LineNumberNode(0, :none)
        end
    else
        __source__
    end
    _analyze_arg(arg) = try
        @match arg begin
            name::Symbol => (; name)
            Expr(:(::), type) => (; type)
            :($name::$type) => (; name, type)
            :($v...) => (; _analyze_arg(v)..., splatting=true)
            Expr(:kw, key, value) => (; _analyze_arg(key)..., default=Some(value))
        end
    catch
        arg
    end
    _analyze(expr) = @match expr begin
        :($header where {$(type_params...)}) => (; _analyze(header)..., type_params)
        Expr(:call, name, Expr(:parameters, kwargs...), args...) ||
            Expr(:call, name, args...) && let kwargs = [] end ||
            :($name($(args...); $(kwargs...))) => (;
            name,
            args=map(parse_argdef, args),
            kwargs=map(parse_argdef, kwargs),
            type_params=[]
        )
    end
    (; name, args, kwargs, type_params) = _analyze(header)
    FuncDef(;
        name,
        args,
        kwargs,
        type_params,
        body,
        line_number
    )
end

deep_esc(expr, excludes) = @match expr begin
    s::Symbol => expr ∈ excludes ? s : esc(s)
    Expr(head, args...) => Expr(head, deep_esc.(args, (excludes,))...)
    _ => esc(expr)
end

"""
    to_expr(::Union{FuncArg, FuncDef}; esc=false, excludes=Symbol[])

Convert a `FuncArg` or `FuncDef` struct to an expression.
`excludes` is a list of symbols that should not be escaped.
"""
function to_expr(funcarg::FuncArg; esc::Bool=false, excludes=Symbol[])
    @destruct FuncArg(
        name,
        type,
        default,
        splatting
    ) = funcarg
    if esc
        if !isnothing(type)
            type = deep_esc(type, excludes)
        end
        if !isnothing(default)
            default = Some(deep_esc(something(default), excludes))
        end
    end
    expr = if isnothing(name)
        @assert !isnothing(type) "Function argument must have a name or a type"
        Expr(:(::), type)
    else
        if isnothing(type)
            name
        else
            Expr(:(::), name, type)
        end
    end
    if splatting
        expr = Expr(:..., expr)
    end
    if isnothing(default)
        expr
    else
        Expr(:kw, expr, something(default))
    end
end
function to_expr(funcdef::FuncDef; esc::Bool=false, short::Bool=false)
    @destruct FuncDef(
        name,
        args,
        kwargs,
        type_params,
        body,
        line_number
    ) = funcdef
    excludes = if length(type_params) > 0
        map(type_params) do s
            @match s begin
                Expr(:(<:), s::Symbol, _) => s
                _ => s
            end
        end
    else
        Symbol[]
    end
    if esc
        name = Base.esc(name)
    end
    header = :($name($(to_expr.(args; esc, excludes)...); $(to_expr.(kwargs; esc, excludes)...)))
    if length(type_params) > 0
        header = :($header where {$(type_params...)})
    end
    if isnothing(body)
        header
    elseif short
        Expr(:(=), header, body)
    else
        Expr(:function, header, body)
    end
end
to_expr(funcarg::Expr; esc::Bool=false, excludes=Symbol[]) = esc ? deep_esc(funcarg, excludes) : funcarg
to_expr(funcarg::Symbol; esc::Bool=false, excludes=Symbol[]) = esc ? deep_esc(funcarg, excludes) : funcarg

Base.convert(::Type{Expr}, funcdef::FuncDef) = to_expr(funcdef)
