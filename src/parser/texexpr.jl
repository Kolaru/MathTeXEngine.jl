const _math_font_mappings = Dict(
    :bb => to_blackboardbold,
    :cal => to_caligraphic,
    :frak => to_frakture,
    :scr => to_caligraphic
)

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
    args::Vector{Any}

    function TeXExpr(head, args::Vector)
        # Convert math font like `\mathbb{R}` -- TeXExpr(:font, [:bb, 'R']) --
        # to unicode symbols -- e.g. TeXExpr(:symbol, 'ℝ')
        if length(args) == 2 && head == :font && haskey(_math_font_mappings, args[1])
            font, content = args
            to_font = _math_font_mappings[font]
            return leafmap(content) do leaf
                sym = only(leaf.args)
                return TeXExpr(:symbol, to_font(sym))
            end
        end

        return new(head, args)
    end
end

TeXExpr(head) = TeXExpr(head, [])
TeXExpr(head, args...) = TeXExpr(head, collect(args))
TeXExpr(head, arg) = TeXExpr(head, [arg])

Base.push!(texexpr::TeXExpr, arg) = push!(texexpr.args, arg)
Base.pop!(texexpr::TeXExpr) = pop!(texexpr.args)
Base.copy(texexpr::TeXExpr) = TeXExpr(texexpr.head, deepcopy(texexpr.args))

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
    expr = texparse(str[2:end-1])
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
isleaf(texexpr::TeXExpr) = texexpr.head in (:char, :delimiter, :digit, :punctuation, :symbol)
isleaf(::Nothing) = true

function AbstractTrees.children(texexpr::TeXExpr)
    isleaf(texexpr) && return TeXExpr[]
    return texexpr.args
end

function AbstractTrees.printnode(io::IO, texexpr::TeXExpr)
    if isleaf(texexpr)
        print(io, "TeXExpr :$(texexpr.head) '$(only(texexpr.args))'")
    else
        print(io, "TeXExpr :$(texexpr.head)")
    end
end

function Base.show(io::IO, texexpr::TeXExpr)
    print_tree(io, texexpr, maxdepth=10)
end

function Base.:(==)(tex1::TeXExpr, tex2::TeXExpr)
    childs1 = children(tex1)
    childs2 = children(tex2)

    length(childs1) != length(childs2) && return false

    return all(childs1 .== childs2)
end

"""
    leafmap(f, texexpr::TeXExpr)

Return a TeXExpr with the same structure, but all leaf expression `leaf`
replaced by `f(leaf)`.
"""
function leafmap(f, texexpr::TeXExpr)
    isleaf(texexpr) && return f(texexpr)

    args = map(texexpr.args) do arg
        arg isa TeXExpr || return arg
        return leafmap(f, arg)
    end

    return TeXExpr(texexpr.head, args)
end
