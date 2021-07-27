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
    else
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
        TeXParseError("Unexpected '}' at position $(p-1)", stack, p, data))
    group = pop!(stack)

    # Remove nestedness for group with a single element
    if length(group.args) == 1
        group = first(group.args)
    end

    if requirement(stack) == :argument
        push_to_current!(stack, group)

        command_builder = current(stack)
        head, required_n_args, args... = command_builder.args

        if required_n_args == length(args)
            pop!(stack)
            command = TeXExpr(head, args)
            push_to_current!(stack, command)
        end
    else
        push_to_current!(stack, group)
    end
end

function _push_char!(stack, p, data)
    if current_head(stack) == :skip_char
        pop!(stack)
    elseif isvalid(data, p-1)
        char = data[prevind(data, p)]
        symbol = get(symbol_to_canonical, char, char)
        push_to_current!(stack, symbol)
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

_begin_command_builder!(stack, p, data) = push!(stack, TeXExpr(:command_builder))

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
        err = TeXParseError(
            "end of string reached with unfinished $(current(stack).head)",
            stack, p_eof, data)
        throw(err)
    end

    return current(stack)
end
