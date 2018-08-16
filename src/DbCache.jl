__precompile__()
module DbCache

import LibPQ

using Compat, DataStreams, Missings

@static if VERSION >= v"0.7.0-DEV.2575"
    using Distributed
else
    import Base.close
    using NamedTuples
    if !(:close in getfield.(methodswith(LibPQ.Result), :name))
        close(r::LibPQ.Result) = clear!(r)
    end
end

export
    # types
    Conn,
    Stmt,
    Res,
    DBCache,
    IDType,
    IDDimensionType,

    # macros
    @idinstance,
    @iddimension,

    # functions
    stmt_dict,
    transaction,
    id_check,
    load!,
    load_no_id!,
    id!,
    _id!,
    get_id,
    id_in_cache,
    stmt,
    select_vals,
    insert_vals,
    num_rows,
    execute

# package code goes here
include("dblayer.jl")
include("dbcache.jl")

end # module
