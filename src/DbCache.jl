module DbCache

import LibPQ

using Tables

export
    # types
    Conn, Stmt, Res, DBCache, IDType, IDDimensionType,
    # macros
    @idinstance, @iddimension,
    # functions
    stmt_dict, transaction, id_check, load!, load_no_id!,
    id!, _id!, get_id, id_in_cache, stmt, select_vals, insert_vals

include("dblayer.jl")
include("dbcache.jl")

end # module
