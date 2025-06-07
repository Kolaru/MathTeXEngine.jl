struct TeXParseError <: Exception
    msg::String
    stack::Stack
    position::Int
    tex
end

function Base.showerror(io::IO, e::TeXParseError)
    println(io, "TeXParseError: ",  e.msg)
    show_state(io, e.stack, e.position, e.tex)
    show_tokenization(io, tex)
end

function show_tokenization(io, tex)
    println(io, "TeX expression tokenized as")
    println(io, "index : token_type [length]")
    for (i, len, token) in tokenize(TeXToken, tex)
        println(io, "$i : $token [$len]")
    end
    println(io)
end

show_tokenization(tex) = show_tokenization(stdout, tex)

function show_state(io::IO, stack, position, tex)
    # Everything is shifted by one
    if position > lastindex(tex)
        println(io, "after the end of the latex string")
        println(io, tex)
    else
        # Compute the index of the char from the byte index
        position_to_id = zeros(Int, lastindex(tex))
        id = 0
        for p in 1:lastindex(tex)
            if isvalid(tex, p)
                id += 1
            end
            position_to_id[p] = id
        end
        p = position_to_id[position]
        println(io, "at position ", position, " (string index ", p, ")")
        println(io, tex)
        println(io, " " ^ (p - 1), "^")
    end

    println(io, "Stack")
    show_stack(io, stack)
    println(io)
end

show_state(stack, position, tex) = show_state(stdout, stack, position, tex)

function show_stack(io, stack)
    for (k, level) in enumerate(stack)
        K = length(stack) - k + 1
        print(io, "[$K] ", level)
    end
end

show_stack(stack) = show_stack(stdout, stack)

function push_down!(stack)
    top = pop!(stack)
    if head(top) == :group
        # Replace empty groups by 0 spaces
        if isempty(top.args)
            top = TeXExpr(:space, 0.0)
        # Unroll group with single elements
        elseif length(top.args) == 1
            top = only(top.args)
        end
    end
    push!(first(stack), top)

    if head(first(stack)) in [:subscript, :superscript]
        decoration = pop!(stack)
        decorated = pop!(first(stack))
        decorated.args[subsuperindex(head(decoration))] = first(decoration.args)
        push!(first(stack).args, decorated)
    end

    conclude_command!!(stack)
end

function conclude_command!!(stack)
    com = first(stack)
    head(com) != :command && return false
    nargs = length(com.args) - 1

    if required_args(first(com.args)) == nargs
        pop!(stack)
        push!(stack, command_expr(com.args[1], com.args[2:end]))
        push_down!(stack)
    end
end

function subsuperindex(dec)
    if dec == :subscript
        return 2
    elseif dec == :superscript
        return 3
    end
    error()
end

function delimiter(com_str, str)
    str = str[length(com_str)+1:end]
    if length(str) == 1
        return TeXExpr(:delimiter, only(str))
    else
        return only(texparse(str).args)
    end
end

"""
    texparse(tex::String ; showdebug=false)

Parse a string representing a single LaTeX expression into nested TeXExpr.

See the documentation for the possible combinations of expression head and
arguments.

Setting `showdebug` to `true` show a very verbose break down of the parsing.
"""
function texparse(tex ; root = TeXExpr(:lines), showdebug = false)
    if showdebug
        show_tokenization(tex)
    end

    contains_math = occursin(raw"$", tex)

    stack = Stack{Any}()
    inside_math = false
    push!(stack, root)
    push!(stack, TeXExpr(:line))

    for (pos, len, token) in tokenize(TeXToken, tex)
        if showdebug
            show_state(stack, pos, tex)
        end
        # Skip the invalid part of unicode characters
        !isvalid(tex, pos) && continue

        try
            if token == dollar
                if head(first(stack)) == :inline_math
                    inside_math = false
                    push_down!(stack)
                else
                    inside_math = true
                    push!(stack, TeXExpr(:inline_math))
                end
            elseif token == newline
                if length(stack) > 2
                    throw(TeXParseError("unexpected new line", stack, length(tex), tex))
                end

                push_down!(stack)
                push!(stack, TeXExpr(:line))
            elseif token == lcurly
                push!(stack, TeXExpr(:group))
            elseif token == rcurly
                if head(first(stack)) != :group
                    throw(TeXParseError("missing closing '}'", stack, pos, tex))
                end
                push_down!(stack)
            elseif token == left
                push!(stack, TeXExpr(:delimited, delimiter(raw"\left", tex[pos:pos+len-1])))
            elseif token == right
                delimited = pop!(stack)
                if head(delimited) != :delimited
                    throw(TeXParseError("missing closing delimiter", stack, pos, tex))
                end
                left_delim, content... = delimited.args
                right_delim = delimiter(raw"\right", tex[pos:pos+len-1])
                if length(content) == 1
                    content = only(content)
                else
                    content = TeXExpr(:group, content)
                end

                push!(first(stack), TeXExpr(:delimited, [left_delim, content, right_delim]))
            elseif token == command
                com_str = tex[pos:pos+len-1]
                push!(stack, TeXExpr(:command, [com_str]))
                conclude_command!!(stack)
            elseif token == underscore || token == caret || token == primes
                dec = (token == underscore) ? :subscript : :superscript

                if isempty(first(stack).args)
                    core = TeXExpr(:space, 0.0)
                else
                    core = pop!(first(stack))
                end

                if !(head(core) in [:decorated, :underover, :integral])
                    core = TeXExpr(:decorated, [core, nothing, nothing])
                end

                if !isnothing(core.args[subsuperindex(dec)])
                    throw(TeXParseError("multiple $token given", stack, pos, tex))
                end

                push!(first(stack), core)

                if token == primes
                    core.args[subsuperindex(dec)] = TeXExpr(:primes, len)
                else
                    push!(stack, TeXExpr(dec))
                end
            elseif token == char
                c = tex[pos]

                # hyphen replaced by minus sign if expression does not contain
                # inline math at all, or the hyphen is inside inline math
                if c == '-'
                    if !contains_math || inside_math
                        expr = TeXExpr(:spaced, TeXExpr(:symbol, '−'))
                    else
                        expr = TeXExpr(:char, '-')
                    end
                else
                    expr = canonical_expr(c)
                end
                push!(stack, expr)
                push_down!(stack)
            end
        catch err
            throw(TeXParseError("unexpected error", stack, pos, tex))
        end
    end

    if head(first(stack)) == :line
        push_down!(stack)
    end

    if length(stack) > 1
        throw(TeXParseError("unexpected end of input", stack, length(tex), tex))
    end

    lines = only(stack)
    if length(lines.args) == 1
        return only(lines.args)
    else
        return lines
    end
end
