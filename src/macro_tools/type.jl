"""
    @krecord struct MyStruct
        a::Int = 1
        b::Float64
    end

Macro to define a struct with keyword arguments and `MLStyle.@as_record`,
and following generic functions are defined:
- `copy`
"""
@public macro krecord(structdef)
    name = capture_names(structdef, __module__) |> only
    quote
        Base.@kwdef $structdef
        $MLStyle.@as_record $name
        Base.copy(x::$name) = Base.deepcopy(x)
        Core.@__doc__ $name
    end |> esc
end
@declared_names Base.@kwdef(body) = body
@declared_names @krecord(body) = body

"""
    @kenum EnumName[::BaseType] value1[=x] value2[=y]
    @kenum EnumName begin
        value1
        value2
    end
    @kenum ExistingEnum

Macro to define a Julia-style enum that supports MLStyle's patten matching.
See `Base.@enum`.
"""
@public macro kenum(name, rest...)
    Tname = @match name begin
        :($EnumName::$BaseType) => EnumName
        _ => name
    end
    def = if length(rest) === 0
        nothing
    else
        :(Core.@__doc__ Base.@enum $name $(rest...))
    end
    quote
        $def
        $(MLStyle).is_enum(::$Tname) = true
        $(MLStyle).pattern_uncall(e::$Tname, _, _, _, _) = $(MLStyle.AbstractPatterns.literal)(e)
        $Tname
    end |> esc
end
@declared_names @kenum(args...) = args
@declared_names Base.@enum(args...) = args
