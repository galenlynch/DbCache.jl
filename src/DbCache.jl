__precompile__()
module DbCache
using ODBC, Compat

export
    # types
    Conn,
    Stmt,
    DBCache,
    IDType,
    IDDimensionType,

    # macros
    @idinstance,
    @iddimension,

    # functions
    execute!,
    stmt_dict,
    prepare,
    query,
    transaction,
    id_check,
    load!,
    id!,
    get_id,
    id_in_cache,
    stmt,
    select_vals,
    insert_vals

# package code goes here
include("dblayer.jl")
include("dbcache.jl")

end # module
