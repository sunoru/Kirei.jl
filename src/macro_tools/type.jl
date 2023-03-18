"""
    @kstruct struct MyStruct
        a::Int = 1
        b::Float64
    end

Macro to define a struct with keyword arguments and `MLStyle.@as_record`,
and following generic functions are defined:
- `copy`
"""
@public macro kstruct(structdef)
    name = capture_name(structdef, __module__)
    quote
        Base.@kwdef $structdef
        $MLStyle.@as_record $name
        Base.copy(x::$name) = Base.deepcopy(x)
        $name
    end |> esc
end
