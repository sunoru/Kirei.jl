"""
    get_bindings(pattern::Expr, [__module__])
"""
function get_bindings(pattern::Expr, __module__::Module=Main)
    result = Set{Symbol}()
    _analyze(pat, is_literal) = @switch pat begin
        @case ::QuoteNode
            _analyze(pat.value, true)
        @case if is_literal end && Expr(:$, args...)
            foreach(x -> _analyze(x, false), args)
        @case if is_literal end && Expr(_, args...)
            foreach(x -> _analyze(x, true), args)
        @case if is_literal end && _
        @case :_
        @case ::Symbol && if isdefined(__module__, pat) && MLStyle.is_enum(getfield(__module__, pat)) end
            # nothing
        @case ::Symbol
            push!(result, pat)
        @case Expr(:quote, args...)
            foreach(x -> _analyze(x, true), args)
        @case :(Do($(args...)))
            foreach(args) do arg
                @when let Expr(:kw, key::Symbol, _) = arg
                    push!(result, key)
                end
            end
        @case :($a || $b)
            _analyze(a, false)
            _analyze(b, false)
        # extract fields
        @case Expr(:kw, _, v)
            _analyze(v, false)
        @case Expr(:(::), v, _...)
            _analyze(v, false)
        # dict pattern
        @case :(Dict($(args...)))
            foreach(args) do arg
                @when let :($_ => $v) = arg
                    _analyze(v, false)
                end
            end
        # app pattern
        @case :($_($(args...)))
            foreach(x -> _analyze(x, false), args)
        # other expr
        @case Expr(_, args...)
            foreach(x -> _analyze(x, false), args)
        @case _
    end
    _analyze(pattern, false)
    result
end

"""
    @destruct lhs = rhs [err_msg]

Destruct `rhs` into `lhs`. Similar to `@when let lhs = rhs`, but the destructed
values are available in the current scope, and it throws an error if the pattern
does not match.
"""
@public macro destruct(expr, err_msg=nothing)
    lhs, rhs = @match expr begin
        Expr(:(=), lhs, rhs) => (lhs, rhs)
        _ => error("Usage: @destruct lhs = rhs")
    end
    bindings = get_bindings(lhs, __module__)
    binding_tuple = Expr(:tuple, bindings...)
    if isnothing(err_msg)
        err_msg = :("Failed to destruct: $(result)")
    end
    quote
        result = $(esc(rhs))
        $(esc(binding_tuple)) = @when let $lhs = result
            $(binding_tuple)
        @otherwise
            error($err_msg)
        end
        result
    end
end
