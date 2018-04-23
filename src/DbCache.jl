__precompile__()
module DbCache
using Compat, DataStreams, NamedTuples, Missings
import LibPQ

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
