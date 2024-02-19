struct Priorityfunction
    expression
    nn_mask::Vector{Bool}
    max::Vector{Float32}
    min::Vector{Float32}
end

function Priorityfunction(s::String,
                max::Union{Vector{Number},Number}=1,
                min::Union{Vector{Number},Number}=-1)

    features = ["PT", "DD", "RO", "RW", "ON", "JS", "ST", "NI", "NW", "SLA", "EW", "JWM","CW", "CJW", "CT","TT", "BSA", "DBA", "RF"]
    mask = [true for _ in features]

    for i in eachindex(features)
        s = replace(s, features[i] => "w.ω_" * features[i] * " * f." * features[i])
        mask[i] = occursin(features[i],s)
    end

    f = Meta.parse("(w,f) -> " * s)
    expr = eval(f)

    if max isa Number
        max = [max for i in mask if i]
    end
    if min isa Number
        min = [min for i in mask if i]
    end
    if sum(mask) == 0
        error("no features selected")
    end
    if max isa Vector{Number}
        if length(max) != sum(mask)
            error("max vector has wrong length")
        end
    end
    if min isa Vector{Number}
        if length(min) != sum(mask)
            error("min vector has wrong length")
        end
    end

    Priorityfunction(expr,mask,max,min)
end

function PriorityfunctionfromTree(tree)
    # TODO generate an expression from a tree input!
    error("not done yet")
end
