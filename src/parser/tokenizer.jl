tex_tokens = [
    :char => re".",
    :primes => re"'+",
    :caret => re"\^",
    :underscore => re"_",
    :rcurly => re"}",
    :lcurly => re"{",
    :command => re"\\[a-zA-Z]+" | re"\\.",
    :right => re"\\right.",
    :left => re"\\left.",
    :newline => (re"\\" * re"\\") | re"\\n",
    :dollar => re"$"
]

@eval @enum TeXToken error $(first.(tex_tokens)...)
make_tokenizer((error, 
    [TeXToken(i) => j for (i, j) in enumerate(last.(tex_tokens))]
)) |> eval