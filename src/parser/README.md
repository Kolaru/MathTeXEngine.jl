# Parse developer documentation

This is a quick introduction on how the parser is working.
It gives a short introduction to each file in the order they are loaded.

## texexpr.jl

This file contains the definition of the `TeXExpr` struct.
It is used as the representation for *all* the outputs of the parser.
It works similarly as Julia built-in expr, having two fields:
- `head::Symbol` : the identifier of the kind of `TeXExpr` used.
    See the main documentation for a list of valid names.
- `args::Vector{Any}` : a list of all the data associated with the expression.
    For example for a `TeXExpr` with head `digit`, `args` is a list containing
    a single element, the digit represented by the expression.
    Arguments can be either `TeXExpr` themselves, or other Julia types,
    typically `Char` or `String`.

## commands_data.jl

This file simply lists family of command for easier registration in the next
step.
It is based on the commands defined for `mathtext` the latex engine of
`matplotlib`.

## commands_registration.jl

In this file we map a single symbol or a string representing a latex
command to its `TeXExpr` representation through the `canonical_expr` function.
For example, the string `"\alpha"` is mapped to `TeXExpr(:symbol, 'α')`.

Here we introduce the concept of a canonical representation.
This simply has to do with the fact that sometime different latex inputs can
lead to the same expression, and we represent them in a unique and
consistent way.
For example, both the strings `"\alpha"` and `"α"` are mapped to the
expression `TeXExpr(:symbol, 'α')`.

Note that the canonical expression may not be the final expression that
the parser outputs.
Sometimes additional informations need to be parsed to complete the command.
In such case, the canonical expression is a `TeXExpr` that is further
modified when the needed information are parsed.
There are currently two main use cases:
- LaTeX macros with arguments, like `\frac`, that are mapped to
    `TeXExpr(:argument_gatherer, [head, number_of_args])` that are converted
    to `TeXExpr(head, args)` once the arguments are parsed and gathered.
- Constructs with optional modifiers, like `\int` that can optionally their
    bounds specified.
    In this case the optional arguments of the expression are initially
    filled with `nothing` and are later replaced with their actual value if
    they are found while parsing.

This strategy allows the parser to only move forward without explicit
lookahead.

## parser.jl

This is where the magic happens, in the `texparse` function.
For the most part it contains the definition of the parser using `Automa.jl`.
A lot need to be learn from `Automa.jl` documentation before diving in here.

In addition to `Automa.jl` native capabilities, to be able to parse a rich
language like latex, we need to manage a stack
that contain both the current state of parsing and the already parsed data.
The strategy is relatively simple:
1. We put a `TeXExpr(:expr, [])` as initial state of the stack.
2. We parse LaTeX strings character by character (`Automa.jl` do it byte by
    byte, some care is needed to do it unicode char by unicode char).
3. When we encouter a new construct, we put its canonical representation on
    top of the stack (e.g. `{` start a new `TeXExpr(:group)`).
4. When we encouter a char that can end the current construct, we finalize it.
    That is we pop it from the stack and apply some final transformation  to it
    if needed (e.g. removing the useless `TeXExpr(:group)` layer for a
    group of a single element).
    Then we add it to the argument list of the first construct below.

Note that some construct, like digits, are composed of only a single char so for them
steps 3 and 4 are merged and they are simply added to the current construct.

Most of the complexity in the file comes from the fact that there are
many special rules for beginning or ending a construct.
Think for example of superscript.
Starting from the string `"10^"`, the superscript construct can be terminated
by either
- A single char e.g. `"10^2"`.
- A command e.g. `"10^\beta"`.
- A group e.g. `"10^{2 + 3}`.

Regardless, at the end, when the parsing is successful, the stack
collapses to a single element, `TeXExpr(:expr)` which arguments contain
a nested representation of the full LaTeX string.

You can watch the rise and fall of the stack by passing `showdebug=true` to
`texparse`.
It is currently not as fun as to watch an old empire rise and fall,
but beware, it is nearly as verbose.