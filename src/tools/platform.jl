_target_os_cond(o) = @match o begin
    :windows => :(Sys.iswindows())
    :linux => :(Sys.islinux())
    :macos => :(Sys.isapple())
    :(not($(ss...))) => Expr(:&&, (:(!$(_target_os_cond(s))) for s in ss)...)
    _ => error("Unsupport OS: $o")
end
_target_arch_cond(o) = @match o begin
    :(not($(ss...))) => Expr(:&&, (:(!$(_target_arch_cond(s))) for s in ss)...)
    _ => :(Sys.ARCH ≡ $(QuoteNode(o)))
end
function _target(expr; os=nothing, arch=nothing)
    os_cond = if isnothing(os)
        :(true)
    else
        os_cond = :(false)
        for o in os
            c = _target_os_cond(o)
            os_cond = :($c || $os_cond)
        end
        os_cond
    end
    arch_cond = if isnothing(arch)
        :(true)
    else
        arch_cond = :(false)
        for a in arch
            c = _target_arch_cond(a)
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
@public macro target(args...)
    argc = length(args)
    argc == 1 && return esc(args[1])
    kwargs = Dict{Symbol, Vector}()
    for i in 1:argc - 1
        kw = args[i]
        push!(kwargs, @match kw begin
            Expr(:(=), k, Expr(:tuple, w...)) => (k=>collect(w))
            Expr(:(=), k, w) => (k=>[w])
        end)
    end
    _target(args[end]; kwargs...)
end

"""
    @target_os OS expr

Evaluate `expr` only on the target OS.

OS is one of `windows`, `linux`, `macos`.
"""
@public macro target_os(targets, expr)
    :(@target os=$targets $(esc(expr)))
end

"""
    @target_arch ARCH expr

Evaluate `expr` only on the target architecture.
"""
@public macro target_arch(targets, expr)
    :(@target arch=$targets $(esc(expr)))
end
