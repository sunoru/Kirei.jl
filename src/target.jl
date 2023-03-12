function _target(expr; os=nothing, arch=nothing)
    os_cond = if isnothing(os)
        :(true)
    else
        os_cond = :(false)
        for o in os
            f = @match o begin
                :windows => :(Sys.iswindows)
                :linux => :(Sys.islinux)
                :macos => :(Sys.isapple)
                _ => error("Unsupport OS: $o")
            end
            os_cond = :($f() || $os_cond)
        end
        os_cond
    end
    arch_cond = if isnothing(arch)
        :(true)
    else
        arch_cond = :(false)
        for a in arch
            c = :(Sys.ARCH ≡ $(QuoteNode(a)))
            arch_cond = :($c || $arch_cond)
        end
        arch_cond
    end
    conditions = :($os_cond && $arch_cond)
    quote
        @static if $conditions
            $(esc(expr))
        end
    end
end

"""
    @target [os=(windows, linux, macos)] [arch=(x86_64, aarch64, ...)] expr

Evaluate `expr` only when the target OS and architecture match the given conditions.

It uses `@static` to evaluate the conditions at parse time.
"""
macro target(args...)
    argc = length(args)
    if argc == 1
        return esc(args[1])
    end
    kwargs = Dict{Symbol, Vector{Symbol}}()
    for i in 1:argc - 1
        kw = args[i]
        push!(kwargs, @match kw begin
            Expr(:(=), k, w::Symbol) => (k=>[w])
            Expr(:(=), k, w::QuoteNode) => (k=>[w])
            Expr(:(=), k, Expr(:tuple, w...)) => (k=>Vector{Symbol}(w))
        end)
    end
    _target(args[end]; kwargs...)
end

"""
    @target_os OS expr

Evaluate `expr` only on the target OS.

OS is one of `windows`, `linux`, `macos`.
"""
macro target_os(targets, expr)
    :(@target os=$targets $(esc(expr)))
end

"""
    @target_arch ARCH expr

Evaluate `expr` only on the target architecture.
"""
macro target_arch(targets, expr)
    :(@target arch=$targets $(esc(expr)))
end
