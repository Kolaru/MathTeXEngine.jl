struct TeXParseError <: Exception
    msg::String
    stack::Stack
    position::Int
    data
end

function Base.showerror(io::IO, e::TeXParseError)
    println(io, "TeXParseError: ",  e.msg)
    show_state(io, e.stack, e.position, e.data)
end

function show_state(io::IO, stack, position, data)
    # Everything is shifted by one
    position -= 1
    if position > lastindex(data)
        println(io, "after the end of the data")
        println(io, data)
    elseif position > 0
        # Compute the index of the char from the byte index
        position_to_id = zeros(Int, lastindex(data))
        id = 0
        for p in 1:lastindex(data)
            if isvalid(data, p)
                id += 1
            end
            position_to_id[p] = id
        end
        p = position_to_id[position]
        println(io, "at position ", position, " (string index ", p, ")")
        println(io, data)
        println(io, " " ^ (p - 1), "^")
    end

    println(io, "Stack before")
    show_stack(io, stack)
    println(io)
end

show_state(stack, position, data) = show_state(stdout, stack, position, data)

function show_stack(io, stack)
    for (k, level) in enumerate(stack)
        K = length(stack) - k + 1
        print(io, "[$K] ", level)
    end
end

show_stack(stack) = show_stack(stdout, stack)

function show_debug_info(stack, position, data, action_name)
    @info "Action " * String(action_name)
    show_state(stack, position, data)
end

# Super and subscript
super = re"\^"
super.actions[:exit] = [:end_command_builder, :setup_decorated, :begin_super]

sub = re"_"
sub.actions[:exit] = [:end_command_builder, :setup_decorated, :begin_sub]

# Groups
lbrace = re"{"
lbrace.actions[:exit] = [:end_command_builder, :begin_group]

rbrace = re"}"
rbrace.actions[:exit] = [:end_command_builder, :end_group, :end_token]

# Commands
bslash = re"\\"
bslash.actions[:exit] = [:end_command_builder, :begin_command_builder]

command_char = re"[A-Za-z]"
command_char.actions[:exit] = [:push_char, :end_token]

# Characters
space = re" "
space.actions[:exit] = [:end_command_builder]
special_char = lbrace | rbrace | bslash | super | sub | command_char | space
other_char = re"." \ special_char
other_char.actions[:exit] = [:end_command_builder, :push_char, :end_token]

mathexpr = re.rep(special_char | other_char)
mathexpr.actions[:exit] = [:end_command_builder]

machine = Automa.compile(mathexpr)

current(stack) = first(stack)
current_head(stack) = head(current(stack))
push_to_current!(stack, arg) = push!(current(stack).args, arg)

const require_token = [
    :subscript,
    :superscript,
    :left_delimiter,
    :right_delimiter
]

function requirement(stack)
    current_head(stack) == :argument_gatherer && return :argument
    current_head(stack) in require_token && return :token
    return :none
end

function end_token!(stack)
    requirement(stack) != :token && return
    token = pop!(stack)

    if current_head(stack) in [:decorated, :underover, :integral]
        decorated = pop!(stack)
        id = head(token) == :subscript ? 2 : 3
        
        !isnothing(decorated.args[id]) && throw(
            TeXParseError("multiple subscripts or superscripts", stack, p, data))
        decorated.args[id] = first(token.args)
        push_to_current!(stack, decorated)
    elseif head(token) == :left_delimiter
        push_to_current!(stack, token)
    elseif head(token) == :right_delimiter
        push_to_current!(stack, token)
        delimited = pop!(stack)

        # Simplify by constructing a single :delimited expr
        left = delimited.args[1]
        right = delimited.args[end]
        args = delimited.args[2:end-1]
        content = length(args) == 1 ? first(args) : TeXExpr(:group, args)
        simplified = TeXExpr(:delimited, [left.args[1], content, right.args[1]])
        push_to_current!(stack, simplified)
    end
end

# Set all command as function to play more nicely with Revise.jl

_begin_group!(stack, p, data) = push!(stack, TeXExpr(:group))

function _end_group!(stack, p, data)
    current_head(stack) != :group && throw(
        TeXParseError("unexpected '}'", stack, p, data))
    group = pop!(stack)

    # Remplace empty groups by a zero-width space
    if isempty(group.args)
        group = TeXExpr(:space, 0.0)
    # Remove nestedness for group with a single element
    elseif length(group.args) == 1
        group = first(group.args)
    end

    push_to_current!(stack, group)

    if requirement(stack) == :argument
        command_builder = current(stack)
        head, required_n_args = command_builder.args[1:2]
        args = command_builder.args[3:end]

        if required_n_args == length(args)
            pop!(stack)
            if head == :begin_env
                # Transform the content of the argument back to a single string
                env_name = String(Char.(first(args).args))
                push!(stack, TeXExpr(:env, Any[env_name]))
                push!(stack, TeXExpr(:env_row))
                push!(stack, TeXExpr(:env_cell))
            elseif head == :end_env
                env_name = String(Char.(args[1].args))
                current(stack).head != :env_cell && throw(
                    TeXParseError(
                        "unexpected end of environnement '$env_name'",
                    stack, p, data))

                cell = pop!(stack)
                push_to_current!(stack, cell)
                row = pop!(stack)
                push_to_current!(stack, row)
                open_env_name = current(stack).args[1]
                env_name != open_env_name && throw(
                    TeXParseError(
                        "found an end for environnement '$env_name', but it is not matching the currently open env",
                    stack, p, data))
                env = pop!(stack)
                push_to_current!(stack, env)
            else
                command = TeXExpr(head, args)
                push_to_current!(stack, command)
            end
        end
    end
end

function _push_char!(stack, p, data)
    current_head(stack) == :skip_char && return pop!(stack)
    !isvalid(data, p-1) && return

    char = data[prevind(data, p)]

    if current_head(stack) == :env_cell && char == '&'
        push_to_current!(stack, pop!(stack))
        push!(stack, TeXExpr(:env_cell))
    else
        push_to_current!(stack, canonical_expr(char))
    end
end

function _end_token!(stack, p, data)
    if isvalid(data, p-1)
        end_token!(stack)
    end
end

_begin_sub!(stack, p, data) = push!(stack, TeXExpr(:subscript))
_begin_super!(stack, p, data) = push!(stack, TeXExpr(:superscript))

function _setup_decorated!(stack, p, data)
    core = pop!(current(stack).args)
    if head(core) ∉ [:decorated, :integral, :underover]
        push!(stack, TeXExpr(:decorated, Any[core, nothing, nothing]))
    else
        push!(stack, core)
    end
end

function _begin_command_builder!(stack, p, data)
    current_head(stack) == :skip_char && return pop!(stack)
    push!(stack, TeXExpr(:command_builder))
end

function _end_command_builder!(stack, p, data)
    if current_head(stack) == :command_builder
        command_builder = pop!(stack)

        args = command_builder.args
        skip_char = false

        # One character command are always tested even if the char is not
        # a letter
        if length(args) == 0
            current_char = data[prevind(data, p)]
            push!(args, current_char)
            skip_char = true
        end

        command_name = String(Char.(args))
        command = "\\" * command_name

        if command_name == "left"
            push!(stack, TeXExpr(:delimited))
            push!(stack, TeXExpr(:left_delimiter))
        elseif command_name == "right"
            current_head(stack) != :delimited && throw(
                TeXParseError("unexpected '\\right' at position $(p-1)",
                stack, p, data))
            push!(stack, TeXExpr(:right_delimiter))
        elseif command_name == "\\"
            current(stack).head != :env_cell && throw(
                TeXParseError("'\\' for newline is only supported inside env",
                stack, p, data))
            current_cell = pop!(stack)
            push_to_current!(stack, current_cell)
            current_row = pop!(stack)
            push_to_current!(stack, current_row)
            push!(stack, TeXExpr(:env_row))
            push!(stack, TeXExpr(:env_cell))
        elseif haskey(command_to_canonical, command)
            expr = command_to_canonical[command]

            if head(expr) == :argument_gatherer
                push!(stack, expr)
            else
                push_to_current!(stack, expr)
                end_token!(stack)
            end
        else
            throw(
                TeXParseError("unsupported command $command",
                stack, p, data))
        end

        if skip_char
            push!(stack, TeXExpr(:skip_char))
        end
    end
end

action_names = [
    :begin_group, :end_group, :push_char, :end_token, :begin_sub, :begin_super,
    :setup_decorated, :begin_command_builder, :end_command_builder]

actions = map(action_names) do action_name
    function_name = Symbol("_" * String(action_name) * "!")

    return action_name => quote
        if showdebug
            show_debug_info(stack, p, data, $(QuoteNode(action_name)))
        end

        $function_name(stack, p, data)

        if showdebug
            println("Stack after")
            show_stack(stack)
            println()
        end
    end
end

actions = Dict(actions...)

context = Automa.CodeGenContext()
@eval function texparse(data ; showdebug=false)
    # Allows string to start with _ or ^
    if !isempty(data) && (data[1] == '_' || data[1] == '^')
        data = "{}" * data
    end

    $(Automa.generate_init_code(context, machine))
    p_end = p_eof = lastindex(data)

    # Needed to avoid problem with multi bytes unicode chars
    stack = Stack{Any}()
    push!(stack, TeXExpr(:expr))

    try
        $(Automa.generate_exec_code(context, machine, actions))
    catch
        throw(TeXParseError("unexpected error while parsing", stack, p, data))
    end

    while current_head(stack) == :skip_char
        pop!(stack)
    end

    if length(stack) > 1 
        throw(TeXParseError(
            "end of string reached with unfinished $(current(stack).head)",
            stack, p_eof, data))
    end

    final_expr = current(stack)
    # Never return an empty expression
    if isempty(final_expr.args)
        push!(final_expr.args, TeXExpr(:space, 0.0))
    end
    return final_expr
end

@doc """
    texparse(data::String ; showdebug=false)

Parse a string representing a single LaTeX expression into nested TeXExpr.

See the documentation for the possible combinations of expression head and
arguments.

Setting `showdebug` to `true` show a very verbose break down of the parsing.
""" texparse

"""
    texparse(data::LaTeXString ; showdebug=false)

Parse a LaTeXString composed of a single LaTeX math expression into nested
TeXExpr.
"""
texparse(data::LaTeXString ; showdebug=false) = texparse(data[2:end-1] ; showdebug=showdebug)