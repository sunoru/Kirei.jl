function gen_forward(Typ, field, methods, __source__)
    defs = map(methods) do method
        method, type_params = @when let :($m where $(T...)) = method
            m, T
        @otherwise
            method, []
        end
        f, pre_args = @when let :($f($(args...))) = method
            f, args
        @otherwise
            method, []
        end
        f = esc(f)
        pre_args = map(pre_args) do arg
            @match arg begin
                ::Symbol => arg
                :(::$T) => :($(gensym())::$(esc(T)))
                :($s::$T) => :($s::$(esc(T)))
            end
        end
        pre_argnames = map(pre_args) do arg
            @match arg begin
                ::Symbol => arg
                :($s::$_) => s
            end
        end
        args, kwargs = gensym(), gensym()
        Expr(
            :(=),
            :(($f)($(pre_args...), t::$(esc(Typ)), $args...; $kwargs...) where $(esc.(type_params)...)),
            Expr(:block,
                __source__,
                :(($f)($(pre_argnames...), t.$field, $args...; $kwargs...))
            )
        )
    end
    Expr(:block, defs...)
end

"""
    @forward Foo.bar f, g(io::IO), h{T}(::Int, arg2) where T

Forward methods `f`, `g`, `h` of `Foo` to `Foo.bar`.
It is similar to `MacroTools.@forward`, but it supports arguments before the given type.

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

"""
    @head_default f([io::IO=stdout], a::Int, b=0)

Generate a function `f` that has default values for the arguments at the beginning of the argument list.
Note that you need to specify the types of some arguments to prevent ambiguity.

It is usually recommended to only default at most one argument that has a unique type.

The above is equivalent to
```julia
f(io::IO, a::Int) = f(io, a, 0)
f(a::Int, b) = f(stdout, a, b)
f(a::Int) = f(stdout, a, 0)
```

You can also use `@head_default` before a function definition.
"""
@public macro head_default(funcdef)
    funcdef = FuncDef(funcdef)

    num_defaults = findfirst((@λ begin
        Expr(:vect, _...) => false
        _ => true
    end), funcdef.args)
    num_defaults = if isnothing(num_defaults)
        0
    else
        num_defaults - 1
    end
    isnothing(findnext((@λ begin
        Expr(:vect, _...) => true
        _ => false
    end), funcdef.args, num_defaults + 1)) || error("Default arguments should be at the beginning.")

    _parse(arg) = let new_arg = parse_argdef(arg)
        @assert !new_arg.splatting "Splatting is not allowed in head default arguments."
        @destruct FuncArg(; name, type) = new_arg
        # Set `new_arg.default` to nothing
        FuncArg(; name, type)
    end
    original_impl = if isnothing(funcdef.body)
        nothing
    else
        original_impl = copy(funcdef)
        empty!(original_impl.args)
        for arg in funcdef.args
            @switch arg begin
            @case Expr(:vect, args...)
                push!(original_impl.args, _parse.(args)...)
            @case _
                push!(original_impl.args, arg)
            end
        end
        original_impl
    end
    head_args = funcdef.args[1:num_defaults]
    tail_args = funcdef.args[num_defaults + 1:end]
    defs = Expr[]
    @destruct FuncDef(; name=funcname, kwargs, type_params, line_number) = funcdef
    call_kwargs = map(kwargs) do kwarg
        @destruct FuncArg(; name, splatting) = kwarg
        if splatting
            Expr(:..., name)
        else
            name
        end
    end
    call_tail_args = map(tail_args) do arg
        @destruct FuncArg(; name, splatting) = arg
        if splatting
            Expr(:..., name)
        else
            name
        end
    end
    emitted = zeros(Bool, num_defaults)
    dfs(i) = if i > num_defaults
        all(!, emitted) && return
        # Generate the function definition
        args = FuncArg[]
        call_args = []
        for j in 1:num_defaults
            if !emitted[j]
                parsed = _parse.(head_args[j].args)
                push!(args, parsed...)
                push!(call_args, map(x -> x.name, parsed)...)
            else
                for arg in head_args[j].args
                    @destruct FuncArg(; default=Some(default)) = parse_argdef(arg)
                    push!(call_args, default)
                end
            end
        end
        push!(args, tail_args...)
        push!(call_args, call_tail_args...)
        body = Expr(
            :block,
            line_number,
            :($(esc(funcname))($(call_args...); $(call_kwargs...)))
        )
        def = FuncDef(;
            name=funcname,
            args,
            kwargs,
            type_params,
            body,
            line_number
        )
        push!(defs, to_expr(def, esc=true, short=true))
    else
        emitted[i] = false
        dfs(i + 1)
        emitted[i] = true
        dfs(i + 1)
    end
    dfs(1)
    Expr(
        :block,
        isnothing(original_impl) ? nothing : :(Core.@__doc__ $(to_expr(original_impl, esc=true))),
        defs...
    )
end
