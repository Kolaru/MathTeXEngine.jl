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

    println(io, "with stack (length $(length(stack))):")
    for (k, level) in enumerate(stack)
        println(io, "[$k] ", level)
    end
end

show_state(stack, position, data) = show_state(stdout, stack, position, data)

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
special_char = lbrace | rbrace | bslash | super | sub | command_char | space
other_char = re"." \ special_char
other_char.actions[:enter] = [:end_command_builder]
other_char.actions[:exit] = [:push_char, :end_token]

mathexpr = re.rep(special_char | other_char)
mathexpr.actions[:all] = [:show_debug_info]
mathexpr.actions[:exit] = [:end_command_builder]

machine = Automa.compile(mathexpr)

current(stack) = first(stack)
current_head(stack) = head(current(stack))
push_to_current!(stack, arg) = push!(current(stack).args, arg)

number_of_arguments = Dict(
    :frac => 2,
    :sqrt => 1,
    :accent => 1,
    :mathfont => 1
)

function has_all_arguments(texexpr)
    required = get(number_of_arguments, head(texexpr), 0)
    return required <= length(texexpr.args)
end

const require_token = [
    :subscript,
    :superscript,
    :left_delimiter,
    :right_delimiter
]

function requirement(stack)
    !has_all_arguments(current(stack)) && return :argument
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
        content = TeXExpr(:group, delimited.args[2:end-1])
        simplified = TeXExpr(:delimited, [left.args[1], content, right.args[1]])
        push_to_current!(stack, simplified)
    end
end

actions = Dict(
    :show_debug_info => quote
        if showdebug
            @info "New transition"
            show_state(stack, p, data)
        end
    end,
    :begin_group => quote
        push!(stack, TeXExpr(:group))
    end,
    :end_group => quote
        current_head(stack) != :group && throw(
            TeXParseError("Unexpected '}' at position $(p-1)", stack, p, data))
        group = pop!(stack)

        # Remove nestedness for group with a single element
        if length(group.args) == 1
            group = first(group.args)
        end

        if requirement(stack) == :argument
            push_to_current!(stack, group)

            if has_all_arguments(current(stack))
                command = pop!(stack)
                push_to_current!(stack, command)
            end
        else
            push_to_current!(stack, group)
        end
    end,
    :push_char => quote
        if isvalid(data, p-1)
            char = data[prevind(data, p)]
            push_to_current!(stack, get_symbol_expr(char))
        end
    end,
    :end_token => quote
        if isvalid(data, p-1)
            end_token!(stack)
        end
    end,
    :begin_sub => quote
        push!(stack, TeXExpr(:subscript))
    end,
    :begin_super => quote
        push!(stack, TeXExpr(:superscript))
    end,
    :setup_decorated => quote
        core = pop!(current(stack).args)
        if head(core) ∉ [:decorated, :integral, :underover]
            push!(stack, TeXExpr(:decorated, Any[core, nothing, nothing]))
        else
            push!(stack, core)
        end
    end,
    :begin_command_builder => quote
        push!(stack, TeXExpr(:command_builder))
    end,
    :end_command_builder => quote
        if current_head(stack) == :command_builder
            command_builder = pop!(stack)
            command_name = String(Char.(command_builder.args))

            if command_name == "frac"
                push!(stack, TeXExpr(:frac))
            elseif command_name == "sqrt"
                push!(stack, TeXExpr(:sqrt))
            elseif command_name == "left"
                push!(stack, TeXExpr(:delimited))
                push!(stack, TeXExpr(:left_delimiter))
            elseif command_name == "right"
                current_head(stack) != :delimited && throw(
                    TeXParseError("unexpected '\\right' at position $(p-1)",
                    stack, p, data))
                push!(stack, TeXExpr(:right_delimiter))
            elseif is_supported_command(command_name)
                push_to_current!(stack, get_command_expr(command_name))
                end_token!(stack)
            else
                throw(
                    TeXParseError("unsupported command \\$command_name",
                    stack, p, data))
            end
        end
    end
)

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
        # Workaround for vscode not showing the source error
        println("unexpected error while parsing")
        show_state(stderr, stack, p, data)
        println("original error:")
        rethrow()

        rethrow(TeXParseError("unexpected error while parsing", stack, p, data))
    end

    if length(stack) > 1
        err = TeXParseError(
            "end of string reached with unfinished $(current(stack).head)",
            stack, p_eof, data)
        throw(err)
    end

    return current(stack)
end
