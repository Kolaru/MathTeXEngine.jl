##
## Spaced symbols
##
# Symbols that need extra space around them

binary_operator_symbols = split("+ * −")
binary_operator_commands = split(raw"""
    \pm             \sqcap                   
    \mp             \sqcup                   
    \times          \vee                     
    \div            \wedge                   \oplus
    \ast            \setminus                \ominus
    \star           \wr                      \otimes
    \circ           \diamond                 \oslash
    \bullet         \bigtriangleup           \odot
    \cdot           \bigtriangledown         \bigcirc
    \cap            \triangleleft            \dagger
    \cup            \triangleright           \ddagger
    \uplus          \amalg""")

relation_symbols = split(raw"= < > :")
relation_commands = split(raw"""
    \leq        \geq        \equiv   \models
    \prec       \succ       \sim     \perp
    \preceq     \succeq     \simeq   \mid
    \ll         \gg         \asymp   \parallel
    \subset     \supset     \approx  \bowtie
    \subseteq   \supseteq   \cong    \join
    \sqsubset   \sqsupset   \neq     \smile
    \sqsubseteq \sqsupseteq \doteq   \frown
    \in         \ni         \propto  \vdash
    \dashv      \dots       \dotplus""")

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
    \rightleftharpoons""")

spaced_symbols = first.(vcat(binary_operator_symbols, relation_symbols))
spaced_commands = vcat(binary_operator_commands, relation_commands, arrow_commands)

##
## Subsuper commands
##
# Functions and symbols that expect subscript and/or superscript

underover_commands = split(raw"""
    \sum \prod \coprod \bigcap \bigcup \bigsqcup \bigvee
    \bigwedge \bigodot \bigotimes \bigoplus \biguplus""")

underover_functions = split(raw"lim liminf limsup inf sup min max")
integral_commands = split(raw"\int \oint")

##
## Generic functions
##

generic_functions = split(raw"""
    arccos csc ker arcsin deg lg Pr arctan det sec arg dim
    sin cos exp sinh cosh gcd ln sup cot hom log tan
    coth tanh""")

##
## Spaces
##

space_commands = Dict(
    raw"\,"         => 0.16667,   # 3/18 em = 3 mu
    raw"\thinspace" => 0.16667,   # 3/18 em = 3 mu
    raw"\/"         => 0.16667,   # 3/18 em = 3 mu
    raw"\>"         => 0.22222,   # 4/18 em = 4 mu
    raw"\:"         => 0.22222,   # 4/18 em = 4 mu
    raw"\;"         => 0.27778,   # 5/18 em = 5 mu
    raw"\ "         => 0.33333,   # 6/18 em = 6 mu
    raw"\enspace"   => 0.5,       # 9/18 em = 9 mu
    raw"\quad"      => 1,         # 1 em = 18 mu
    raw"\qquad"     => 2,         # 2 em = 36 mu
    raw"\!"         => -0.16667,  # -3/18 em = -3 mu
)

space_symbols = Dict(
    '~'          => 0.33333,   # 6/18 em = 6 mu, nonbreakable
)

##
## Accents
##

combining_accents = [
    raw"\hat",
    raw"\breve",
    raw"\bar",
    raw"\grave",
    raw"\acute",
    raw"\tilde",
    raw"\dot",
    raw"\ddot",
    raw"\vec"
]

punctuation_symbols = split(raw", ; . !")
delimiter_symbols = split(raw"| / ( ) [ ] < >")
font_names = split(raw"rm cal it tt sf bf default bb frak scr regular")

# TODO Add to the parser what come below, if needed
wide_accent_commands = split(raw"\widehat \widetilde \widebar")