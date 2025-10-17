# Utilities to read (parts of) the MATH table stored in OpenType Math fonts
# See 
# https://learn.microsoft.com/en-us/typography/opentype/spec/math
# https://freetype.org/freetype2/docs/reference/ft2-truetype_tables.html
module OpenTypeMathTable

import FreeTypeAbstraction: FreeType, FTFont, check_error
import FreeTypeAbstraction.FreeType: libfreetype, FT_Face, FT_Error, FT_ULong, FT_Long, 
    FT_UInt32, FT_Byte, FT_FWord, FT_UFWord

const FT_TAG = FT_UInt32

function FT_MAKE_TAG(_x1, _x2, _x3, _x4)
    return convert(FT_TAG, (
        ( convert( FT_TAG, _x1 ) << 24 ) | 
        ( convert( FT_TAG, _x2 ) << 16 ) | 
        ( convert( FT_TAG, _x3 ) <<  8 ) | 
        convert( FT_TAG, _x4 )         
    ))
end

const TTAG_MATH = FT_MAKE_TAG('M','A','T','H')

struct MathHeaderTable
    major_version :: UInt16
    minor_version :: UInt16
    math_constants_offset :: UInt16
    math_glyph_info_offset :: UInt16
    math_variants_offset :: UInt16
end

function MathHeaderTable(buffer::IOBuffer)
    seekstart(buffer)
    major_version = read(buffer, UInt16) |> ntoh
    minor_version = read(buffer, UInt16) |> ntoh
    math_constants_offset = read(buffer, UInt16) |> ntoh
    math_glyph_info_offset = read(buffer, UInt16) |> ntoh
    math_math_variants_offset = read(buffer, UInt16) |> ntoh
    return MathHeaderTable(
        major_version, minor_version, math_constants_offset, math_glyph_info_offset, math_math_variants_offset
    )
end

struct MathValueRecord
    value :: FT_FWord
    offset :: UInt16
end

struct MathTable
    face :: FTFont
    buffer :: IOBuffer
    header :: MathHeaderTable
    constants :: Dict{Symbol, Union{Int16, FT_UFWord, MathValueRecord}}
end

function Base.show(io::IO, mtable::MathTable)
    print(io, "MathTable (with constants $(length(mtable.constants)))")
end

function MathTable(face::FTFont; throw_error::Bool=true)
    buffer = _get_math_table_buffer(face; throw_error)
    if isnothing(buffer)
        return buffer
    end
    header = MathHeaderTable(buffer)
    constants = _read_math_constants(buffer, header)
    return MathTable(face, buffer, header, constants)
end

function get_math_constant(::Nothing, symb, default, scaled=true)
    return default
end
function get_math_constant(mtab::MathTable, symb, default, scaled=true)
    v = get(mtab.constants, symb, nothing)
    isnothing(v) && return default
    if isa(v, MathValueRecord)
        v = v.value
        if scaled
            v /= mtab.face.units_per_EM
        end
    end
    return v
end

function _get_math_table_buffer(face::FTFont; throw_error::Bool=true)
    tag = TTAG_MATH
    offset = 0
    length = Ref(zero(UInt64))
    buffer = Ptr{Cvoid}()

    ## first call, determine length
    err = @lock face.lock ccall(
        (:FT_Load_Sfnt_Table, libfreetype), 
        FT_Error, 
        (FT_Face, FT_TAG, FT_Long, Ptr{FT_Byte}, Ptr{FT_ULong},),
        face, tag, offset, buffer, length 
    )
    if err != 0
        if throw_error
            error("Could not load MATH table, error code = $(err).")
        else
            return nothing
        end
    end
    
    ## allocate memory for second call to actually load the table
    n = Int(length[])
    buffer = Vector{FT_Byte}(undef, n)
    err = @lock face.lock ccall(
        (:FT_Load_Sfnt_Table, libfreetype), 
        FT_Error, 
        (FT_Face, FT_TAG, FT_Long, Ptr{FT_Byte}, Ptr{FT_ULong},),
        face, tag, offset, buffer, length 
    )
    if err != 0
        if throw_error
            error("Could not load MATH table, error code = $(err).")
        else
            return nothing
        end
    end
     
    return IOBuffer(buffer)
end

function _read_math_constants(buffer::IOBuffer, header::MathHeaderTable)
    constants = Dict{Symbol, Union{Int16, FT_UFWord, MathValueRecord}}()

    seek(buffer, header.math_constants_offset)

    constants[:scriptPercentScaleDown] = read(buffer, Int16) |> ntoh
    constants[:scriptScriptPercentScaleDown] = read(buffer, Int16) |> ntoh

    constants[:delimitedSubFormulaMinHeight] = read(buffer, FT_UFWord) |> ntoh
    constants[:displayOperatorMinHeight] = read(buffer, FT_UFWord) |> ntoh

    constants[:mathLeading] = _read_math_value_record(buffer)
    constants[:axisHeight] = _read_math_value_record(buffer)
    constants[:accentBaseHeight] = _read_math_value_record(buffer)
    constants[:flattenedAccentBaseHeight] = _read_math_value_record(buffer)
    constants[:subscriptShiftDown] = _read_math_value_record(buffer)
    constants[:subscriptTopMax] = _read_math_value_record(buffer)
    constants[:subscriptBaselineDropMin] = _read_math_value_record(buffer)
    constants[:superscriptShiftUp] = _read_math_value_record(buffer)
    constants[:superscriptShiftUpCramped] = _read_math_value_record(buffer)
    constants[:superscriptBottomMin] = _read_math_value_record(buffer)
    constants[:superscriptBaselineDropMax] = _read_math_value_record(buffer)
    constants[:subSuperscriptGapMin] = _read_math_value_record(buffer)
    constants[:superscriptBottomMaxWithSubscript] = _read_math_value_record(buffer)
    constants[:spaceAfterScript] = _read_math_value_record(buffer)
    constants[:upperLimitGapMin] = _read_math_value_record(buffer)
    constants[:upperLimitBaselineRiseMin] = _read_math_value_record(buffer)
    constants[:lowerLimitGapMin] = _read_math_value_record(buffer)
    constants[:lowerLimitBaselineDropMin] = _read_math_value_record(buffer)
    constants[:stackTopShiftUp] = _read_math_value_record(buffer)
    constants[:stackTopDisplayStyleShiftUp] = _read_math_value_record(buffer)
    constants[:stackBottomShiftDown] = _read_math_value_record(buffer)
    constants[:stackBottomDisplayStyleShiftDown] = _read_math_value_record(buffer)
    constants[:stackGapMin] = _read_math_value_record(buffer)
    constants[:stackDisplayStyleGapMin] = _read_math_value_record(buffer)
    constants[:stretchStackTopShiftUp] = _read_math_value_record(buffer)
    constants[:stretchStackBottomShiftDown] = _read_math_value_record(buffer)
    constants[:stretchStackGapAboveMin] = _read_math_value_record(buffer)
    constants[:stretchStackGapBelowMin] = _read_math_value_record(buffer)
    constants[:fractionNumeratorShiftUp] = _read_math_value_record(buffer)
    constants[:fractionNumeratorDisplayStyleShiftUp] = _read_math_value_record(buffer)
    constants[:fractionDenominatorShiftDown] = _read_math_value_record(buffer)
    constants[:fractionDenominatorDisplayStyleShiftDown] = _read_math_value_record(buffer)
    constants[:fractionNumeratorGapMin] = _read_math_value_record(buffer)
    constants[:fractionNumDisplayStyleGapMin] = _read_math_value_record(buffer)
    constants[:fractionRuleThickness] = _read_math_value_record(buffer)
    constants[:fractionDenominatorGapMin] = _read_math_value_record(buffer)
    constants[:fractionDenomDisplayStyleGapMin] = _read_math_value_record(buffer)
    constants[:skewedFractionHorizontalGap] = _read_math_value_record(buffer)
    constants[:skewedFractionVerticalGap] = _read_math_value_record(buffer)
    constants[:overbarVerticalGap] = _read_math_value_record(buffer)
    constants[:overbarRuleThickness] = _read_math_value_record(buffer)
    constants[:overbarExtraAscender] = _read_math_value_record(buffer)
    constants[:underbarVerticalGap] = _read_math_value_record(buffer)
    constants[:underbarRuleThickness] = _read_math_value_record(buffer)
    constants[:underbarExtraDescender] = _read_math_value_record(buffer)
    constants[:radicalVerticalGap] = _read_math_value_record(buffer)
    constants[:radicalDisplayStyleVerticalGap] = _read_math_value_record(buffer)
    constants[:radicalRuleThickness] = _read_math_value_record(buffer)
    constants[:radicalExtraAscender] = _read_math_value_record(buffer)
    constants[:radicalKernBeforeDegree] = _read_math_value_record(buffer)
    constants[:radicalKernAfterDegree] = _read_math_value_record(buffer)

    constants[:radicalDegreeBottomRaisePercent] = read(buffer, Int16) |> ntoh

    return constants
end

function _read_math_value_record(buffer)
    value = read(buffer, FT_FWord) |> ntoh
    offset = read(buffer, UInt16) |> ntoh
    return MathValueRecord(value, offset)
end

end#module