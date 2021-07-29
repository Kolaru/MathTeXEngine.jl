"""
    TeXExpr(head::Symbol, args::Vector)

A TeX expression, represented by a head and any number of arguments.

See the documentation to see the valid combinations of head and arguments,
and the meaning of the latter.
"""
struct TeXExpr
    head::Symbol
    args::Vector

    TeXExpr(head, args::Vector) = new(head, args)
end

TeXExpr(head) = TeXExpr(head, [])
TeXExpr(head, args...) = TeXExpr(head, collect(args))
TeXExpr(head, arg) = TeXExpr(head, [arg])

function Base.Char(texexpr::TeXExpr)
    if texexpr.head in [:char, :symbol, :digit]
        return texexpr.args[1]
    end

    throw(ArgumentError("cannot convert TeXExpr with head $(texexpr.head) to Char."))
end

"""
    manual_texexpr(data)

Convenience function to manually create a TeXExpr from tuples or latex strings.

# Example
julia> manual_texexpr((:expr, 'a', (:spaced, '+'), raw"\\omega^2"))
TeXExpr :expr
├─ 'a'
├─ TeXExpr :spaced
│  └─ '+'
└─ TeXExpr :decorated
   ├─ TeXExpr :symbol
   │  ├─ 'ω'
   │  └─ "\\omega"
   ├─ nothing
   └─ '2'
```
"""
function manual_texexpr(tuple::Tuple)
    head = tuple[1]
    args = []

    if head in [:char, :digit, :symbol]
        return TeXExpr(head, tuple[2])
    end

    for arg in tuple[2:end]
        push!(args, manual_texexpr(arg))
    end

    return TeXExpr(head, args)
end

function manual_texexpr(str::LaTeXString)
    expr = texparse(str[2:end])
    if length(expr.args) == 1
        return first(expr.args)
    else
        return TeXExpr(:group, expr.args)
    end
end

manual_texexpr(char::Char) = TeXExpr(:char, char)
manual_texexpr(any) = any

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
