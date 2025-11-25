const token_command = re"\\[a-zA-Z]+" | re"\\."
tex_tokens = [
    :char => re".",
    :primes => re"'+",
    :caret => re"\^",
    :underscore => re"_",
    :rcurly => re"}",
    :lcurly => re"{",
    :command => token_command, 
    :right => re"\\right." | re"\\right" * token_command,
    :left => re"\\left." | re"\\left" * token_command,
    :newline => (re"\\" * re"\\") | re"\\n",
    :dollar => re"$"
]

@eval @enum TeXToken error $(first.(tex_tokens)...)
make_tokenizer((error, 
    [TeXToken(i) => j for (i, j) in enumerate(last.(tex_tokens))]
)) |> eval