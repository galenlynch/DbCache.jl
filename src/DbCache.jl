__precompile__()
module DbCache
using ODBC

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
    prepare,
    query,
    transaction,
    id_check,
    load!,
    id!,
    stmt,
    select_vals,
    insert_vals

# package code goes here
include("dblayer.jl")
include("dbcache.jl")

end # module
