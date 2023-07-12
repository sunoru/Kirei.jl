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

"""
    @kenum EnumName[::BaseType] value1[=x] value2[=y]
    @kenum EnumName begin
        value1
        value2
    end

Macro to define a Julia-style enum that supports MLStyle's patten matching.
See `Base.@enum`.
"""
@public macro kenum(name, rest...)
    Tname = @match name begin
        :($EnumName::$BaseType) => EnumName
        _ => name
    end
    quote
        Core.@__doc__ Base.@enum $name $(rest...)
        $(MLStyle).is_enum(::$Tname) = true
        $(MLStyle).pattern_uncall(e::$Tname, _, _, _, _) = $(MLStyle.AbstractPatterns.literal)(e)
        $Tname
    end |> esc
end
