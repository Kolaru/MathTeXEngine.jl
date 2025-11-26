# This file takes inspiration from source file `um-code-usv.dtx`
# of the UNICODE-MATH package  <wspr.io/unicode-math>

# We generate two mappings in here:
#
# `const ucmchars_by_alphabet_style_name = all_chars()`
#
# `ucmchars_by_alphabet_style_name` is a dict-of-dict-of-dict (?)
# * alphabet (:Greek, :greek, :Latin, …)
#   => style (:up, :bfup, …) 
#     => name ("a", "Gamma", "1", … )
#        => ucm_ch::UCMChar
#
# `const chars_to_ucmchars = inverse_ucm_dict(ucmchars_by_alphabet_style_name)`
#
# `chars_to_ucmchars` is an inverse look-up dict, mapping 
# glyphs of type `Char` to UCMChars (if they are defined in `ucmchars_by_alphabet_style_name`)

"""
    UCMChar(; name, alphabet, style, glyph)

Internal type decorating a `glyph::Char` with meta data."""
Base.@kwdef struct UCMChar
    name :: String
    alphabet :: Symbol
    style :: Symbol
    glyph :: Char
end

function Base.show(io::IO, ucmchar::UCMChar)
    print(io, "UCMChar('$(ucmchar.glyph)')")
end

## helper: "theta" ↦ "Theta", "vartheta" ↦ "varTheta" …
_cap(n) = startswith(n, "var") ? "var" * uppercasefirst(n[4:end]) : uppercasefirst(n)
## helper: "Theta" ↦ "theta", "varTheta" ↦ "vartheta" …
_decap(n) = startswith(n, "var") ? "var" * lowercasefirst(n[4:end]) : lowercasefirst(n)

# ## Greek Alphabet
const names_Greek = (
    "Alpha", "Beta", "Gamma", "Delta", "Epsilon", 
    "Zeta", "Eta", "Theta", "Iota", "Kappa",
    "Lambda", "Mu", "Nu", "Xi", "Omicron",
    "Pi", "Rho", "varTheta", "Sigma", "Tau", 
    "Upsilon", "Phi", "Chi", "Psi", "Omega",
)

## starting indices for glyph ranges in unicode
const usv_Greek = Dict(
    :up => 0x391,
    :it => 0x1D6E2,
    :bfup => 0x1D6A8,
    :bfit => 0x1D71C,
    :bfsfup => 0x1D756,
    :bfsfit => 0x1D790
)

## additional glyphs
const extras_Greek = Dict(
    :up => Dict(
        "varTheta" => 0x3F4,
        "Digamma" => 0x3DC,
    ),
    :bfup => Dict(
        "varTheta" => 0x1D6B9,
        "Digamma" => 0x1D7CA,
    ),
    :it => Dict(
        "varTheta" => 0x1D6F3,
    ),
    :bfit => Dict(
        "varTheta" => 0x1D72D,
    ),
    :bfsfit => Dict(
        "varTheta" => 0x1D7A1,
    ),
    :bb => Dict(
        "Gamma" => 0x213E,
        "Pi" => 0x0213F,
    )
)

# ## greek Alphabet

## generate lowercase names
const names_greek = begin 
    ng = _decap.(names_Greek) |> collect

    # rename according to LaTeX conventions:
    for i in eachindex(ng)
        if ng[i] == "phi" || ng[i] == "epsilon"
            ng[i] = "var" * ng[i]
        end
    end
    tuple(ng...)
end

const usv_greek = Dict(
    :up => 0x3B1,
    :it => 0x1D6FC,
    :bfup => 0x1D6C2,
    :bfit => 0x1D736,
    :bfsfup => 0x1D770,
    :bfsfit => 0x1D7AA,
)

const extras_greek = Dict(
    :up => Dict(
        "epsilon" => 0x3F5,
        "vartheta" => 0x3D1,
        "varkappa" => 0x3F0,
        "phi" => 0x3D5,
        "varrho" => 0x3F1,
        "varpi" => 0x3D6,
        "digamma" => 0x3DD,
    ),
    :it => Dict(
        "epsilon" => 0x1D716,
        "vartheta" => 0x1D717,
        "varkappa" => 0x1D718,
        "phi" =>      0x1D719,
        "varrho" =>   0x1D71A,
        "varpi" =>    0x1D71B,
    ),
    :bfit => Dict(
        "epsilon" => 0x1D750,
        "vartheta" => 0x1D751,
        "varkappa" => 0x1D752,
        "phi" => 0x1D753,
        "varrho" => 0x1D754,
        "varpi" => 0x1D755,
    ),
    :bfup => Dict(
        "epsilon" => 0x1D6DC,
        "vartheta" => 0x1D6DD,
        "varkappa" => 0x1D6DE,
        "phi" => 0x1D6DF,
        "varrho" => 0x1D6E0,
        "varpi" => 0x1D6E1,
        "digamma" => 0x1D7CB,
    ),
    :bfsfup => Dict(
        "epsilon" =>  0x1D78A,
        "vartheta" => 0x1D78B,
        "varkappa" => 0x1D78C,
        "phi" =>      0x1D78D,
        "varrho" =>   0x1D78E,
        "varpi" =>    0x1D78F,
    ),
    :bfsfit => Dict(
        "epsilon" =>  0x1D7C4,
        "vartheta" => 0x1D7C5,
        "varkappa" => 0x1D7C6,
        "phi" =>      0x1D7C7,
        "varrho" =>   0x1D7C8,
        "varpi" =>    0x1D7C9,
    ),
    :bb => Dict(
        "gamma" => 0x0213D,
        "pi" => 0x0213C,
    )
)

# ## Latin
const names_Latin = (
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R",
    "S", "T", "U", "V", "W", "X", "Y", "Z"
)

const usv_Latin = Dict(
    :up => 65,
    :it => 0x1D434,
    :bb => 0x1D538,
    :cal => 0x1D49C,
    :frak => 0x1D504,
    :sfup => 0x1D5A0,
    :sfit => 0x1D608,
    :tt => 0x1D670,
    :bfup => 0x1D400,
    :bfit => 0x1D468,
    :bffrak => 0x1D56C,
    :bfcal => 0x1D4D0,
    :bfsfup => 0x1D5D4,
    :bfsfit => 0x1D63C,
)

extras_Latin = Dict(
    :cal => Dict(
        "B" => 0x212C,
        "E" => 0x2130,
        "F" => 0x2131,
        "H" => 0x210B,
        "I" => 0x2110,
        "L" => 0x2112,
        "M" => 0x2133,
        "R" => 0x211B,
    ),
    :bb => Dict(
        "C" =>          0x2102,
        "H" =>          0x210D,
        "N" =>          0x2115,
        "P" =>          0x2119,
        "Q" =>          0x211A,
        "R" =>          0x211D,
        "Z" =>          0x2124,
    ),
    :frak => Dict(
        "C" => 0x212D,
        "H" => 0x210C,
        "I" => 0x2111,
        "R" => 0x211C,
        "Z" => 0x2128,
    ),
    :bbit => Dict(
        "D" => 0x2145
    )
)

# ## latin Alphabet
const names_latin = _decap.(names_Latin)

const extras_latin = Dict(
    :cal => Dict(
        "e" => 0x212F,
        "g" => 0x210A,
        "o" => 0x2134
    ),
    :it => Dict(
        "h" => 0x0210E,
    ),
    :bbit => Dict(
        "d" => 0x2146,
        "e" => 0x2147,
        "i" => 0x2148,
        "j" => 0x2149,
    )
)
const usv_latin = Dict(
    :up => 97,
    :it => 0x1D44E,
    :bb => 0x1D552,
    :cal => 0x1D4B6,
    :frak => 0x1D51E,
    :sfup => 0x1D5BA,
    :sfit => 0x1D622,
    :tt => 0x1D68A,
    :bfup => 0x1D41A,
    :bfit => 0x1D482,
    :bffrak => 0x1D586,
    :bfcal => 0x1D4EA,
    :bfsfup => 0x1D5EE,
    :bfsfit => 0x1D656
)

# ## Numbers
const names_num = ("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
const usv_num = Dict(
    :up => 48,
    :bb => 0x1D7D8,
    :sfup => 0x1D7E2,
    :tt => 0x1D7F6,
    :bfup => 0x1D7CE,
    :bfsfup => 0x1D7EC
)

# ## Singletons
# ### partial
const names_partial = ("partial",)
const usv_partial = Dict(
    :up => 0x02202,
    :it => 0x1D715,
    :bfup => 0x1D6DB,
    :bfit => 0x1D74F,
    :bfsfup => 0x1D789,
    :bfsfit => 0x1D7C3,
)
# ### Nabla
const names_Nabla = ("Nabla",)
const usv_Nabla = Dict(
    :up => 0x02207,
    :it => 0x1D6FB,
    :bfup => 0x1D6C1,
    :bfit => 0x1D735,
    :bfsfup => 0x1D76F,
    :bfsfit => 0x1D7A9,
)

# ### dotless
const names_dotless = ("dotlessi", "dotlessj")
const usv_dotless = Dict(
    :up => 0x00131,
    :it => 0x1D6A4
)
const extras_dotless = Dict(
    :up => Dict(
        "dotlessj" => 0x00237,
    ),
    :it => Dict(
        "dotlessi" => 0x1D6A4,
    )
)

const ucmchars_dotless = Dict(
    :up => Dict(
        "dotlessi" => UCMChar(; name="dotlessi", glyph=Char(0x00131), alphabet=:dotless, style=:up),
        "dotlessj" => UCMChar(; name="dotlessi", glyph=Char(0x00237), alphabet=:dotless, style=:up)
    ),
    :it => Dict(
        "dotlessi" => UCMChar(; name="dotlessi", glyph=Char(0x1D6A4), alphabet=:dotless, style=:it),
        "dotlessj" => UCMChar(; name="dotlessi", glyph=Char(0x1D6A5), alphabet=:dotless, style=:it),
    )
)

"""
    all_ucmchars()

Internal helper function to generate/collect all nested dict of available `UCMChars`."""
function all_ucmchars()
    global ucmchars_dotless
    ucmchars_Greek = collect_ucmchars(names_Greek, usv_Greek, extras_Greek; alphabet=:Greek)
    ucmchars_greek = collect_ucmchars(names_greek, usv_greek, extras_greek; alphabet=:greek)

    ucmchars_Latin = collect_ucmchars(names_Latin, usv_Latin, extras_Latin; alphabet=:Latin)
    ucmchars_latin = collect_ucmchars(names_latin, usv_latin, extras_latin; alphabet=:latin)
    ucmchars_num = collect_ucmchars(names_num, usv_num; alphabet=:num)

    ucmchars_Nabla = collect_ucmchars(names_Nabla, usv_Nabla; alphabet=:Nabla)
    ucmchars_partial = collect_ucmchars(names_partial, usv_partial; alphabet=:partial)

    return Dict(
        :Greek => ucmchars_Greek,
        :greek => ucmchars_greek,
        :Latin => ucmchars_Latin,
        :latin => ucmchars_latin,
        :num => ucmchars_num,
        :Nabla => ucmchars_Nabla,
        :partial => ucmchars_partial,
        :dotless => ucmchars_dotless
    )
end

"""
    collect_ucmchars(
        char_names, usv_dict, extras_dict=Dict(); 
        alphabet, fixes=Dict())

Given a vector of character names `char_names::AbstractVector{String}`, 
and a dictionary mapping style symbols (`:up`, `:it`) to unicode points, 
collect all the glyphs as `UCMChar` objects.
The returned dict has structure `Dict(style_symb => Dict(name => ucm_char))`.

* `fixes` is a global `Char`-to-`Char` dict, overwriting characters independent of style.
* `extras_dict` can be used to overwrite characters or define additional symbols.
"""
function collect_ucmchars(
    char_names,
    usv_dict,
    extras_dict=Dict();
    alphabet=:UnknownAlphabet,
    fixes=Dict{Char,Char}()
)
    ucm_dict = Dict{Symbol, Dict{String, UCMChar}}()

    for (sn, cp) in pairs(usv_dict)
        dict_sn = Dict(
            n => let ch = Char(cp + i - 1);
                UCMChar(;
                    name=n, glyph=get(fixes, ch, ch), style=sn, alphabet)
            end for (i, n) = enumerate(char_names) 
        )
        ucm_dict[sn] = dict_sn
    end

    for (sn, extras) in pairs(extras_dict)
        if !haskey(ucm_dict, sn)
            dict_sn = Dict{String, UCMChar}()
            ucm_dict[sn] = dict_sn
        else
            dict_sn = ucm_dict[sn]
        end
        for (n, cp) in pairs(extras)
            if haskey(dict_sn, n)
                @unpack name, style = dict_sn[n]
                dict_sn[n] = UCMChar(;
                    glyph=Char(cp), alphabet=dict_sn[n].alphabet, name, style)
            else
                dict_sn[n] = UCMChar(;
                    name=n, glyph=Char(cp), style=sn, alphabet)
            end
        end
    end
    return ucm_dict
end

function inverse_ucm_dict(ucm_dict)
    d = Dict{Char, UCMChar}()
    for (rn, chd) = pairs(ucm_dict)
        for (sn, ucms) = pairs(chd)
            for (n, uch) = pairs(ucms)
                ch = uch.glyph
                if haskey(d, ch)
                    @warn """
                    '$(ch)' already assigned:
                    is : alphabet=$(d[ch].alphabet), style=$(d[ch].style),
                    new: alphabet=$(uch.alphabet), style=$(uch.style)"""
                else
                    d[ch] = uch
                end
            end
        end
    end
    return d
end