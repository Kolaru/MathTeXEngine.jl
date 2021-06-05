const tex_symbols = Dict{String, TeXExpr}()
const command_to_expr = Dict{String, TeXExpr}()
const symbol_to_expr = Dict{Char, TeXExpr}()

function get_symbol_expr(symbol)
    !haskey(symbol_to_expr, symbol) && return symbol
    return copy(symbol_to_expr[symbol])
end

get_command_expr(command) = copy(command_to_expr["\\" * command])
is_supported_command(command) = haskey(command_to_expr, "\\" * command)

for (command, symbol) in latex_symbols
    symbol = first(symbol)  # Convert to Char
    expr = TeXExpr(:symbol, [symbol, command])
    tex_symbols[command] = expr
    command_to_expr[command] = expr
    symbol_to_expr[symbol] = expr
end

# Missing commands
tex_symbols[raw"\neq"] = TeXExpr(:symbol, ['≠', raw"\neq"])

function register_command!(expr_builder, command)
    !haskey(tex_symbols, command) && return

    expr = tex_symbols[command]
    symbol = expr.args[1]
    symbol_to_expr[symbol] = expr_builder(expr)
    command_to_expr[command] = expr_builder(expr)
end

register_command!(head::Symbol, command) = 
    register_command!(symbol -> TeXExpr(head, [symbol]), command)

function register_function!(expr_builder, function_name)
    func = TeXExpr(:function, [function_name])
    command_to_expr["\\" * function_name] = expr_builder(func)
end

register_function!(head::Symbol, command) = 
    register_function!(func -> TeXExpr(head, [func]), command)

function register_symbol!(expr_builder, symbol_char)
    symbol = TeXExpr(:symbol, [symbol_char, String([symbol_char])])
    symbol_to_expr[symbol_char] = expr_builder(symbol)
end

register_symbol!(head::Symbol, command) = 
    register_symbol!(symbol -> TeXExpr(head, [symbol]), command)


binary_operator_symbols = split("+ * -")
binary_operator_commands = split(raw"""
    \pm             \sqcap                   \rhd
    \mp             \sqcup                   \unlhd
    \times          \vee                     \unrhd
    \div            \wedge                   \oplus
    \ast            \setminus                \ominus
    \star           \wr                      \otimes
    \circ           \diamond                 \oslash
    \bullet         \bigtriangleup           \odot
    \cdot           \bigtriangledown         \bigcirc
    \cap            \triangleleft            \dagger
    \cup            \triangleright           \ddagger
    \uplus          \lhd                     \amalg""")

relation_symbols = split(raw"= < > :")
relation_commands = split(raw"""
    \leq        \geq        \equiv   \models
    \prec       \succ       \sim     \perp
    \preceq     \succeq     \simeq   \mid
    \ll         \gg         \asymp   \parallel
    \subset     \supset     \approx  \bowtie
    \subseteq   \supseteq   \cong    \Join
    \sqsubset   \sqsupset   \neq     \smile
    \sqsubseteq \sqsupseteq \doteq   \frown
    \in         \ni         \propto  \vdash
    \dashv      \dots       \dotplus \doteqdot""")

arrow_commands = split(raw"""
    \leftarrow              \longleftarrow           \uparrow
    \Leftarrow              \Longleftarrow           \Uparrow
    \rightarrow             \longrightarrow          \downarrow
    \Rightarrow             \Longrightarrow          \Downarrow
    \leftrightarrow         \longleftrightarrow      \updownarrow
    \Leftrightarrow         \Longleftrightarrow      \Updownarrow
    \mapsto                 \longmapsto              \nearrow
    \hookleftarrow          \hookrightarrow          \searrow
    \leftharpoonup          \rightharpoonup          \swarrow
    \leftharpoondown        \rightharpoondown        \nwarrow
    \rightleftharpoons      \leadsto""")

spaced_symbols = first.(vcat(binary_operator_symbols, relation_symbols))
register_symbol!.(:spaced, spaced_symbols)

spaced_commands = vcat(binary_operator_commands, relation_commands, arrow_commands)
register_command!.(:spaced, spaced_commands)

underover_commands = split(raw"""
    \sum \prod \coprod \bigcap \bigcup \bigsqcup \bigvee
    \bigwedge \bigodot \bigotimes \bigoplus \biguplus""")

underover_functions = split(raw"lim liminf limsup inf sup min max")

register_command!.(
    symbol -> TeXExpr(:underover, Any[symbol, nothing, nothing]),
    underover_commands)
register_function!.(
    symbol -> TeXExpr(:underover, Any[symbol, nothing, nothing]),
    underover_functions)

integral_commands = split(raw"\int \oint")

register_command!.(
    symbol -> TeXExpr(:integral, Any[symbol, nothing, nothing]),
    integral_commands)

generic_functions = split(raw"""
    arccos csc ker arcsin deg lg Pr arctan det sec arg dim
    sin cos exp sinh cosh gcd ln sup cot hom log tan
    coth tanh""")

register_function!.(identity, generic_functions)


# TODO Add to the parser what come below
punctuation_symbols = split(raw", ; . !")
punctuation_commands = split(raw"\ldotp \cdotp")

space_widths = Dict(
    raw"\,"         => 0.16667,   # 3/18 em = 3 mu
    raw"\thinspace" => 0.16667,   # 3/18 em = 3 mu
    raw"\/"         => 0.16667,   # 3/18 em = 3 mu
    raw"\>"         => 0.22222,   # 4/18 em = 4 mu
    raw"\:"         => 0.22222,   # 4/18 em = 4 mu
    raw"\;"         => 0.27778,   # 5/18 em = 5 mu
    raw"\ "         => 0.33333,   # 6/18 em = 6 mu
    raw"~"          => 0.33333,   # 6/18 em = 6 mu, nonbreakable
    raw"\enspace"   => 0.5,       # 9/18 em = 9 mu
    raw"\quad"      => 1,         # 1 em = 18 mu
    raw"\qquad"     => 2,         # 2 em = 36 mu
    raw"\!"         => -0.16667,  # -3/18 em = -3 mu
)

# Autodelim
ambi_delimiters = split(raw"""
    | \| / \backslash \uparrow \downarrow \updownarrow \Uparrow
    \Downarrow \Updownarrow . \vert \Vert \\|""")

left_delimiter = split(raw"( [ \{ < \lfloor \langle \lceil")
right_delimiter = split(raw") ] \} > \rfloor \rangle \rceil")


## Commands using a braced group as an argument
narrow_accent_map = Dict(
    raw"hat"            => raw"\circumflexaccent",
    raw"breve"          => raw"\combiningbreve",
    raw"bar"            => raw"\combiningoverline",
    raw"grave"          => raw"\combininggraveaccent",
    raw"acute"          => raw"\combiningacuteaccent",
    raw"tilde"          => raw"\combiningtilde",
    raw"dot"            => raw"\combiningdotabove",
    raw"ddot"           => raw"\combiningdiaeresis",
    raw"vec"            => raw"\combiningrightarrowabove",
       "\""             => raw"\combiningdiaeresis",
    raw"`"              => raw"\combininggraveaccent",
    raw"'"              => raw"\combiningacuteaccent",
    raw"~"              => raw"\combiningtilde",
    raw"."              => raw"\combiningdotabove",
    raw"^"              => raw"\circumflexaccent",
    raw"overrightarrow" => raw"\rightarrow",
    raw"overleftarrow"  => raw"\leftarrow",
    raw"mathring"       => raw"\circ",
)

wide_accent_commands = split(raw"\widehat \widetilde \widebar")
fontnames = split(raw"rm cal it tt sf bf default bb frak scr regular")