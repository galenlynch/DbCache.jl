function id_check(df::DataFrame)
    local res
    if size(df, 1) > 0
        res = get(df[1, 1])
    else
        res = -1
    end
    return convert(Int, res)
end

immutable DBCache
    db::Conn
    id_cache::Dict{String, Int}
    stmt_cache::Dict{String, Stmt}
end
DBCache(db::Conn) = DBCache(db, Dict{String, Int}(), Dict{String, Stmt}())

@compat abstract type IDType end
@compat abstract type IDDimensionType <: IDType end

"""macro idinstance(typename, [parenttype = IDType], [valuetype = String], [valuetypes...])
Defines a type, typename, with a single value field whose type is either a single value or a tuple of values
"""
macro idinstance(
    typename::Symbol,
    parenttype::Symbol = IDType,
    valuetypes::Vararg{Symbol} = :String
)
    value_is_tuple = length(valuetypes) > 1
    valuetype = value_is_tuple ? :(Tuple{$(valuetypes...)}) : valuetypes[1]
    typedef = quote
        immutable $typename <: $parenttype
            value::$valuetype
        end
    end
    if value_is_tuple
        typedef = quote
            $typedef
            $typename(args...) = $typename(args)
        end
    end
    return esc(typedef)
end

function tablename end
function idname end
function dimname end

macro iddimension(typename::Symbol, tablename_in::Symbol, idname_in::Symbol, dimname_in::Symbol)
    tblstr = string(tablename_in)
    idstr = string(idname_in)
    dimstr = string(dimname_in)
    defs = quote
        @idinstance $typename IDDimensionType
        tablename(::Type{$typename}) = $tblstr
        idname(::Type{$typename}) = $idstr
        dimname(::Type{$typename}) = $dimstr
    end
    return esc(defs)
end

insert_vals{T<:IDType}(id::T) = expand_vals(id.value)
select_vals{T<:IDType}(id::T) = expand_vals(id.value)
expand_vals(v::String) = (v,)
expand_vals(v::Tuple) = v

prepare_error{T}(sym::Symbol, ::Type{T}) = error("No implementation of ", sym, " query for type ", T)

function prepare{T<:IDDimensionType}(db::Conn, ::Type{T}, sym::Symbol)
    thisid = idname(T)
    thistable = tablename(T)
    thisdim = dimname(T)
    if sym == :select
        prepared_stmt = prepare(db, "SELECT $thisid FROM $thistable WHERE $thisdim = ?;")
    elseif sym == :insert
        prepared_stmt = prepare(db, "INSERT INTO $thistable ($thisdim) VALUES (?) RETURNING $thisid;")
    else
        prepare_error(sym, T)
    end
    return prepared_stmt
end

idkey{T<:IDType}(s::T) = "$T/$(s.value)"
idkey{T<:IDType}(::Type{T}, querytype::Symbol) = "$T/$querytype"

function stmt{T<:IDType}(c::DBCache, ::Type{T}, querytype::Symbol)
    key = idkey(T, querytype)
    if haskey(c.stmt_cache, key)
        prepared_stmt = c.stmt_cache[key]
    else
        prepared_stmt = prepare(c.db, T, querytype)
        c.stmt_cache[key] = prepared_stmt
    end
    return prepared_stmt
end

function _load!{T<:IDType}(c::DBCache, s::T, id_stmt::Stmt = stmt(c, T, :insert))
    id_val = id_check(query(id_stmt, insert_vals(s)))
    id_val > 0 || error("Could not load ", T, " with value ", s.value)
    return id_val
end

"Load ID and don't cache it"
function load!{T<:IDType}(c::DBCache, s::T, id_stmt::Stmt = stmt(c, T, :insert))
    return _load!(c, s, id_stmt)
end
function load!{T<:IDType, N}(c::DBCache, S::Array{T, N}, id_stmt::Stmt = stmt(c, T, :insert))
    ns = length(S)
    outs = Array{Int, N}(size(S))
    for idx in eachindex(S)
        outs[idx] = load!(c, S[idx], id_stmt)
    end
    return outs
end

"Get ID and cache it"
function id!{T<:IDType}(c::DBCache, s::T)
    key = idkey(s)
    if haskey(c.id_cache, key)
        id_val = c.id_cache[key]
    else
        id_stmt = stmt(c, T, :select)
        id_val = id_check(query(id_stmt, select_vals(s)))
        if id_val <= 0
            println("SELECT FAILED, id_stmt was ", id_stmt, " and vals were ", select_vals(s))
            id_val = load!(c, s)
        end
        c.id_cache[key] = id_val
    end
    return id_val
end
id!{T<:IDType}(c::DBCache, ins::Array{T}) = [id!(c, s) for s in ins]
