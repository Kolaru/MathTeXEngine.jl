struct TeXExpr
    head::Symbol
    args::Vector
end

TeXExpr(head) = TeXExpr(head, [])
TeXExpr(head, args...) = TeXExpr(head, collect(args))

function manual_texexpr(tuple::Tuple)
    head = tuple[1]
    args = []

    for arg in tuple[2:end]
        if isa(arg, Tuple)
            push!(args, manual_texexpr(arg))
        else
            push!(args, arg)
        end
    end

    return TeXExpr(head, args)
end

head(texexpr::TeXExpr) = texexpr.head
head(::Char) = :char

Base.copy(texexpr::TeXExpr) = TeXExpr(texexpr.head, deepcopy(texexpr.args))

AbstractTrees.children(texexpr::TeXExpr) = texexpr.args
AbstractTrees.printnode(io::IO, texexpr::TeXExpr) = print(io, "TeXExpr :$(texexpr.head)")

function Base.show(io::IO, texexpr::TeXExpr)
    print_tree(io, texexpr, maxdepth=10)
end

function Base.:(==)(tex1::TeXExpr, tex2::TeXExpr)
    childs1 = children(tex1)
    childs2 = children(tex2)
    
    length(childs1) != length(childs2) && return false

    return all(childs1 .== childs2)
end
