function id_check(res::Res)
    if num_rows(res) > 0
        data = Data.stream!(res, NamedTuple)
        entry = data[1][1]
        id_no = ismissing(entry) ? -1 : entry
    else
        id_no = -1
    end
    return convert(Int, id_no)
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
macro idinstance(typename::Symbol, parenttype::Symbol = IDType, valuetypes::Vararg = :String)
    value_is_tuple = length(valuetypes) > 1
    valuetype = value_is_tuple ? :(Tuple{$(valuetypes...)}) : valuetypes[1]

    # Declare type
    typedef = quote
        immutable $typename <: $parenttype
            value::$valuetype
        end
    end

    # Make constructor that takes all arguments and packages them into a tuple
    if value_is_tuple
        num_arg = length(valuetypes)
        argnames = Vector{Symbol}(num_arg)
        argpairs = Vector{Expr}(num_arg)
        for i in 1:num_arg
            sym = gensym()
            argnames[i] = sym
            argpairs[i] = :($sym::$(valuetypes[i]))
        end

        typedef = quote
            $typedef
            $typename($(argpairs...)) = $typename(($(argnames...),))
        end
    end
    return esc(typedef)
end

function tablename end
function idname end
function dimname end

"Expands on the idinstance macro to provide tablename, idname, and dimname functions"
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

expand_vals(v::AbstractArray) = v
expand_vals(v::Tuple) = [v...]
expand_vals(v::Any) = [v]
insert_vals(id::T) where {T<:IDType} = expand_vals(id.value)
select_vals(id::T) where {T<:IDType} = expand_vals(id.value)

stmt_dict(::Type{T}) where {T<: IDType} = Dict{Symbol, String}()

function stmt_dict(::Type{T}) where T<: IDDimensionType
    thisid = idname(T)
    thistable = tablename(T)
    thisdim = dimname(T)
    stmts = Dict(
        :select =>  "SELECT $thisid FROM $thistable WHERE $thisdim = \$1",
        :insert =>  "INSERT INTO $thistable ($thisdim) VALUES (\$1) RETURNING $thisid"
    )
    return stmts
end

function prepare_cached_stmt(db::Conn, ::Type{T}, statement_type::Symbol) where T<:IDType
    stmts = stmt_dict(T)
    if haskey(stmts, statement_type)
        stmt = prepare(db, stmts[statement_type])
    else
        error("No implementation of ", statement_type, " query for type ", T)
    end
    return stmt
end

idkey{T<:IDType}(s::T) = "$T/$(select_vals(s))"
idkey{T<:IDType}(::Type{T}, querytype::Symbol) = "$T/$querytype"

"Make a prepared query and cache it"
function stmt{T<:IDType}(c::DBCache, ::Type{T}, querytype::Symbol)
    key = idkey(T, querytype)
    if haskey(c.stmt_cache, key)
        prepared_stmt = c.stmt_cache[key]
    else
        prepared_stmt = prepare_cached_stmt(c.db, T, querytype)
        c.stmt_cache[key] = prepared_stmt
    end
    return prepared_stmt
end

"Load ID type and don't return ID"
function load_no_id!(c::DBCache, s::T, id_stmt::Stmt = stmt(c, T, :insert)) where T<:IDType
    result = execute(id_stmt, insert_vals(s))
end

"Separate function to actually load values, in case any clean up work needs to be done"
function _load!(c::DBCache, s::T, id_stmt::Stmt = stmt(c, T, :insert)) where T<:IDType
    id_val = id_check(execute(id_stmt, insert_vals(s)))
    id_val > 0 || error("Could not load ", T, " with value ", s.value)
    return id_val
end

"Load ID and don't cache it"
function load!(c::DBCache, s::T, id_stmt::Stmt = stmt(c, T, :insert)) where T<:IDType
    return _load!(c, s, id_stmt)
end
function load!(
    c::DBCache, S::Array{T, N}, id_stmt::Stmt = stmt(c, T, :insert)
) where {T<:IDType, N}
    ns = length(S)
    outs = Array{Int, N}(size(S))
    for idx in eachindex(S)
        outs[idx] = load!(c, S[idx], id_stmt)
    end
    return outs
end

"Get ID and cache it, load if it doesn't exist"
function _id!{T<:IDType}(c::DBCache, s::T)
    key = idkey(s)
    if haskey(c.id_cache, key)
        id_val = c.id_cache[key]
        db_updated = false
    else
        id_stmt = stmt(c, T, :select)
        id_val = id_check(execute(id_stmt, select_vals(s)))
        db_updated = id_val < 0
        if db_updated
            id_val = load!(c, s)
        end
        c.id_cache[key] = id_val
    end
    return id_val, db_updated
end

id!(c::DBCache, s) = _id!(c, s)[1]
id!{T<:IDType}(c::DBCache, ins::Array{T}) = [id!(c, s) for s in ins]

"Get ID and cache it, return -1 if it doesn't exist"
function get_id(c::DBCache, s::T, querytype::Symbol = :select) where T<:IDType
    key = idkey(s)
    if haskey(c.id_cache, key)
        id_val = c.id_cache[key]
    else
        id_stmt = stmt(c, T, querytype)
        id_val = id_check(execute(id_stmt, select_vals(s)))
        if id_val >= 0
            c.id_cache[key] = id_val
        end
    end
    return id_val
end

function id_in_cache(c::DBCache, s::T) where T<:IDType
    key = idkey(s)
    return haskey(c.id_cache, key)
end
