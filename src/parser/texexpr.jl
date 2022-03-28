"""
    TeXExpr(head::Symbol, args::Vector)

A TeX expression, represented by a head and any number of arguments.

See the documentation to see the valid combinations of head and arguments,
and the meaning of the latter.

Fields
======
    - head::Symbol
    - args::Vector
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

to_latex(::Nothing) = nothing

function to_latex(texexpr::TeXExpr)
    head = texexpr.head
    args = texexpr.args

    head in [:char, :digit, :punctuation, :symbol] && return string(first(args))
    head == :function && return "\\$(first(args))"
    head == :frac && return "\\frac{$(to_latex(args[1]))}{$(to_latex(args[2]))}"
    head == :group && return join(to_latex.(args), " ")
    head == :sqrt && return "\\sqrt{$(to_latex(first(args)))}"
    head == :spaced && return string(first(first(args).args))
    head == :space && return ""
    
    if head in [:decorated, :integral, :underover]
        core, sub, sup = to_latex.(args)

        if !isnothing(sub)
            if length(sub) == 1
                core *= "_$sub"
            else
                core *= "_{$sub}"
            end
        end

        if !isnothing(sup)
            if length(sup) == 1
                core *= "^$sup"
            else
                core *= "^{$sup}"
            end
        end
        return core
    end

    # TODO :accent, :space properly

    # Fallback
    return "to_latex($texexpr)"
end

function Base.show(io::IO, ::MIME"text/plain", texexpr::TeXExpr)
    if haskey(io, :compact) && io[:compact]
        print(io, "TeX\"$(to_latex(texexpr))\"")
    else
        return print_tree(io, texexpr, maxdepth=10)
    end
end

function Base.:(==)(tex1::TeXExpr, tex2::TeXExpr)
    childs1 = children(tex1)
    childs2 = children(tex2)
    
    length(childs1) != length(childs2) && return false

    return all(childs1 .== childs2)
end
